// lib/pages/calendar_page/widgets/autocomplete_field.dart

import 'package:flutter/material.dart';

class AutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final List<String> Function(String) getSuggestions;
  final Future<void> Function(String)? onNewValue;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const AutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    required this.getSuggestions,
    this.onNewValue,
    this.validator,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  State<AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<AutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
    } else {
      // Затримка для обробки натискання на елемент списку
      Future.delayed(const Duration(milliseconds: 150), () {
        _hideSuggestions();
      });
    }
  }

  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
    }
  }

  void _updateSuggestions() {
    final query = widget.controller.text;
    final suggestions = widget.getSuggestions(query);
    
    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty && query.isNotEmpty;
    });

    if (_showSuggestions) {
      // Використовуємо WidgetsBinding для отримання розміру після build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuggestionsOverlay();
      });
    } else {
      _hideSuggestions();
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    // Отримуємо розмір та позицію поля
    final RenderBox? renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _selectSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    
    // Додаємо нове значення до автодоповнення якщо потрібно
    widget.onNewValue?.call(suggestion);
    
    _hideSuggestions();
    _focusNode.unfocus();
  }

  void _hideSuggestions() {
    setState(() {
      _showSuggestions = false;
    });
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: _fieldKey, // 👈 Додаємо ключ для отримання розміру
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
          border: const OutlineInputBorder(),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    widget.controller.clear();
                    _hideSuggestions();
                  },
                )
              : null,
        ),
        validator: widget.validator,
        textCapitalization: widget.textCapitalization,
        onFieldSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            widget.onNewValue?.call(value.trim());
          }
        },
      ),
    );
  }
}