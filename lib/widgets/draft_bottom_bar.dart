import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// DRAFT BOTTOM BAR
// Used on every screen in the patient data entry flow.
// Usage,,,
// DraftBottomBar(
// primaryLabel: 'Next — History Taking',
// primaryIcon: Icons.arrow_forward,
// onPrimary: _onNext,
// onSaveDraft: _saveDraftAndExit, // async, shows spinner
// )
// 

class DraftBottomBar extends StatefulWidget {
  final String      primaryLabel;
  final IconData    primaryIcon;
  final VoidCallback onPrimary;
  final Future<void> Function() onSaveDraft;

  const DraftBottomBar({
    super.key,
    required this.primaryLabel,
    this.primaryIcon = Icons.arrow_forward,
    required this.onPrimary,
    required this.onSaveDraft,
  });

  @override
  State<DraftBottomBar> createState() => _DraftBottomBarState();
}

class _DraftBottomBarState extends State<DraftBottomBar> {
  bool _saving = false;

  Future<void> _handleDraft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveDraft();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Primary: Continue 
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sectionHeader,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.primaryLabel,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headerText)),
                  const SizedBox(width: 8),
                  Icon(widget.primaryIcon,
                      color: AppColors.headerText, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Secondary: Save Draft & Exit 
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _saving ? null : _handleDraft,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: AppColors.sectionHeader, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.sectionHeader))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined,
                            color: AppColors.sectionHeader, size: 16),
                        SizedBox(width: 8),
                        Text('Save Draft & Exit',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sectionHeader)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

