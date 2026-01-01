import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/models/stats_model.dart';
import 'package:scrobbler/pages/top_items_page.dart';
import 'package:scrobbler/services/auth_service.dart';
import 'package:scrobbler/widgets/stat_card.dart';
import 'package:scrobbler/widgets/stats_list.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String baseUrl = dotenv.env['API_BASE_URL']!;

  int _totalPlays = 0;
  int _totalMinutes = 0;
  List<TopSong> _topSongs = [];
  List<TopArtist> _topArtists = [];

  late int _selectedMonth; // 0: All time, 1: Jan, 2: Feb,.....
  late int _selectedYear;
  DateTime? _joinedDate;

  bool _isLoading = true;

  Color bgGrey = const Color(0xFF1A1A1A);
  Color sageGreen = const Color(0xFF697565);

  final List<String> _monthNames = [
    "",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchJoinedDate();

    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    fetchStats();
  }

  Future<void> _fetchJoinedDate() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _joinedDate = DateTime.parse(data['created_at']);
        });
      }
    } catch (e) {
      print("Error fetching joined date: $e");
      // Default to start of current year as fallback
      _joinedDate = DateTime(DateTime.now().year, 1, 1);
    }
  }

  Future<void> fetchStats() async {
    String queryParams = ""; // empty query for all time
    if (_selectedMonth != 0 && _selectedYear != 0) {
      queryParams = "?month=$_selectedMonth&year=$_selectedYear";
    }

    try {
      final token = await AuthService.getToken();
      final headers = {"Authorization": "Bearer $token"};

      // Fetch data from server
      final results = await Future.wait([
        http.get(
          Uri.parse("$baseUrl/stats/total$queryParams"),
          headers: headers,
        ),
        http.get(
          Uri.parse("$baseUrl/stats/top-songs$queryParams"),
          headers: headers,
        ),
        http.get(
          Uri.parse("$baseUrl/stats/top-artists$queryParams"),
          headers: headers,
        ),
      ]);

      if (results.every((r) => r.statusCode == 200)) {
        setState(() {
          _totalPlays = jsonDecode(results[0].body)["total_plays"];
          _totalMinutes = jsonDecode(results[0].body)["total_minutes"];

          final List<dynamic> songList = jsonDecode(results[1].body);
          _topSongs = songList.map((e) => TopSong.fromJson(e)).toList();

          final List<dynamic> artistList = jsonDecode(results[2].body);
          _topArtists = artistList.map((e) => TopArtist.fromJson(e)).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching stats: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDateFilterDialog() {
    if (_joinedDate == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isAllTimeSelected = (_selectedMonth == 0 && _selectedYear == 0);

        return AlertDialog(
          backgroundColor: bgGrey,
          title: Text(
            'Select Period',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: ListView(
              children: [
                ListTile(
                  title: Text(
                    'All Time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAllTimeSelected ? Colors.white : Colors.grey,
                      fontSize: 20,
                    ),
                  ),
                  trailing: isAllTimeSelected
                      ? Icon(Icons.check, color: Colors.grey)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMonth = 0;
                      _selectedYear = 0;
                    });
                    Navigator.pop(ctx);
                    fetchStats();
                  },
                ),
                const Divider(height: 1, color: Colors.grey),
                ..._buildDateTree(ctx),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDateTree(BuildContext ctx) {
    List<Widget> yearWidgets = [];
    DateTime now = DateTime.now();
    DateTime start = _joinedDate!;

    for (int year = now.year; year >= start.year; year--) {
      // Determine valid month for the speicifc year
      int startMonth = (year == start.year) ? start.month : 1;
      int endMonth = (year == now.year) ? now.month : 12;

      List<Widget> monthTiles = [];

      // Loop through months (DEC -> JAN)
      for (int month = endMonth; month >= startMonth; month--) {
        bool isSelected = (month == _selectedMonth && year == _selectedYear);

        monthTiles.add(
          ListTile(
            title: Text(
              _monthNames[month],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 16,
              ),
            ),
            trailing: isSelected ? Icon(Icons.check, color: Colors.grey) : null,
            contentPadding: const EdgeInsets.only(left: 32),
            dense: true,
            onTap: () {
              setState(() {
                _selectedMonth = month;
                _selectedYear = year;
              });
              Navigator.pop(ctx);
              fetchStats();
            },
          ),
        );
      }

      yearWidgets.add(
        Theme(
          data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: [
              ExpansionTile(
                title: Text(
                  '$year',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                iconColor: Colors.grey,
                collapsedIconColor: Colors.white,
                // Open if its current year
                initiallyExpanded: year == now.year,
                children: monthTiles,
              ),
              const Divider(height: 1, color: Colors.grey),
            ],
          ),
        ),
      );
    }
    return yearWidgets;
  }

  String _getCurrentFilterLabel() {
    if (_selectedMonth == 0) return 'All Time';
    return '${_monthNames[_selectedMonth]} $_selectedYear';
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text(
            'See All',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color sageGreen = Color(0xFF697565);
    final Color bgGrey = const Color(0xFF1A1A1A);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getCurrentFilterLabel(),
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: bgGrey,
        surfaceTintColor: sageGreen,
        elevation: 12,
        actions: [
          IconButton(
            onPressed: _showDateFilterDialog,
            icon: Icon(Icons.filter_alt, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Your Listening Vibe",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                //---Total Plays---
                Expanded(
                  child: StatCard(
                    title: 'Total Plays',
                    value: _totalPlays,
                    sageGreen: sageGreen,
                  ),
                ),
                const SizedBox(width: 16),
                //---Total Minutes
                Expanded(
                  child: StatCard(
                    title: 'Minutes Listened',
                    value: _totalMinutes,
                    sageGreen: sageGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
            //---Top Songs---
            _buildSectionHeader('Top Songs', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TopItemsPage(
                    title: 'Top Songs',
                    type: 'songs',
                    month: _selectedMonth,
                    year: _selectedYear,
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            TopSongsList(topSongs: _topSongs),

            const SizedBox(height: 40),

            //---Top Artists---
            _buildSectionHeader('Top Artists', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TopItemsPage(
                    title: 'Top Artists',
                    type: 'artists',
                    month: _selectedMonth,
                    year: _selectedYear,
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            TopArtistsList(topArtists: _topArtists),
          ],
        ),
      ),
    );
  }
}
