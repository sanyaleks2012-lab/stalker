// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

class EquipmentSearchBar extends StatefulWidget {
  final void Function(String) onChanged;
  final VoidCallback onCleared;

  const EquipmentSearchBar(
      {super.key, required this.onChanged, required this.onCleared});

  @override
  State<EquipmentSearchBar> createState() => _EquipmentSearchBarState();
}

class _EquipmentSearchBarState extends State<EquipmentSearchBar> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      hintText: "Search...",
      focusNode: focusNode,
      trailing: [
        IconButton(
            onPressed: () {
              controller.clear();
              focusNode.unfocus();
              widget.onCleared();
            },
            icon: const Icon(Icons.clear))
      ],
      onChanged: (text) => widget.onChanged(text),
      controller: controller,
    );
  }
}
