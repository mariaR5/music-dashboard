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
    const sageGreen = Color(0xFF697565);
    const greyAccent = Color(0xFF3B3B3B);

    return TextField(
      controller: widget.fieldController,
      cursorColor: Colors.grey,
      obscureText: widget.isPassword ? true : false,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.isOtp ? '######' : '',
        floatingLabelStyle: TextStyle(color: Colors.white),
        filled: true,
        fillColor: greyAccent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sageGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sageGreen),
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
    const sageGreen = Color(0xFF697565);

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: sageGreen,
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
