import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateNewPasswordPage extends StatefulWidget {
  @override
  _CreateNewPasswordPageState createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(_newPasswordController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password updated successfully')),
        );
        Navigator.of(context).pop(); // Go back to previous screen
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 54),
            HeaderComponent(),
            SizedBox(height: 20),
            Text(
              'Create New',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 36,
                color: Color(0xFF0B7F40),
                height: 46 / 36,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Password',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 36,
                color: Color(0xFF0B7F40),
                height: 46 / 36,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Please enter and confirm your new password.\nYou will need to login after you reset.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
                height: 22 / 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            PasswordInputField(
              label: 'Password',
              showHint: true,
              controller: _newPasswordController,
            ),
            SizedBox(height: 16),
            PasswordInputField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0B7F40),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Reset Password',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.21,
                    color: Colors.white,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class PasswordInputField extends StatefulWidget {
  final String label;
  final bool showHint;
  final TextEditingController controller;

  const PasswordInputField({
    Key? key,
    required this.label,
    this.showHint = false,
    required this.controller,
  }) : super(key: key);

  @override
  _PasswordInputFieldState createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
            height: 22 / 14,
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: '*********',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
                height: 22 / 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  // You can also easily change the color using the color property
                  // color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),
        ),
        if (widget.showHint)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'must contain 8 char.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
                height: 22 / 14,
              ),
            ),
          ),
      ],
    );
  }
}

class HeaderComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF9EF84A),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    'https://dashboard.codeparrot.ai/api/image/Z91XacNZNkcbc4mc/fi-arrow.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}