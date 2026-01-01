import 'package:flutter/material.dart';

class BuildTextField extends StatefulWidget {
  final TextEditingController fieldController;
  final String label;
  final bool isPassword;
  final bool isOtp;

  const BuildTextField({
    super.key,
    required this.fieldController,
    required this.label,
    this.isPassword = false,
    this.isOtp = false,
  });

  @override
  State<BuildTextField> createState() => _BuildTextFieldState();
}

class _BuildTextFieldState extends State<BuildTextField> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: widget.fieldController,
      cursorColor: Colors.grey,
      obscureText: widget.isPassword ? true : false,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.isOtp ? '######' : '',
        floatingLabelStyle: TextStyle(color: Colors.white),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.secondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.secondary),
        ),
      ),
    );
  }
}

class SubmitButton extends StatefulWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onTap;
  const SubmitButton({
    super.key,
    this.isLoading = false,
    required this.label,
    required this.onTap,
  });

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(20),
          ),
        ),
        child: widget.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(),
              )
            : Text(
                widget.label,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
      ),
    );
  }
}
