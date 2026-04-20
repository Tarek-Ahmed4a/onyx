import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class EliteSelectionSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? subtitleBuilder;
  final IconData Function(T)? iconBuilder;
  final bool showSearch;
  final bool allowCustomEntry;
  final T? selectedItem;
  final Color? glowColor;

  const EliteSelectionSheet({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.iconBuilder,
    this.showSearch = true,
    this.allowCustomEntry = false,
    this.selectedItem,
    this.glowColor,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
    IconData Function(T)? iconBuilder,
    bool showSearch = true,
    bool allowCustomEntry = false,
    T? selectedItem,
    Color? glowColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EliteSelectionSheet<T>(
        title: title,
        items: items,
        labelBuilder: labelBuilder,
        subtitleBuilder: subtitleBuilder,
        iconBuilder: iconBuilder,
        showSearch: showSearch,
        allowCustomEntry: allowCustomEntry,
        selectedItem: selectedItem,
        glowColor: glowColor,
      ),
    );
  }

  @override
  State<EliteSelectionSheet<T>> createState() => _EliteSelectionSheetState<T>();
}

class _EliteSelectionSheetState<T> extends State<EliteSelectionSheet<T>> {
  late List<T> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((item) => widget
              .labelBuilder(item)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.glowColor ?? theme.colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          // Glass effect
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      widget.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                ),
              ),

              // Search
              if (widget.showSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterItems,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredItems.length +
                      (widget.allowCustomEntry && _searchController.text.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Custom Entry Item at the top
                    if (widget.allowCustomEntry &&
                        _searchController.text.isNotEmpty &&
                        index == 0) {
                      final query = _searchController.text.toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, query as T);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Use '$query'",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        ),
                                        const Text(
                                          "Enter as custom ticker",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Adjust index if custom entry is shown
                    final actualIndex = (widget.allowCustomEntry &&
                            _searchController.text.isNotEmpty)
                        ? index - 1
                        : index;
                    
                    final item = _filteredItems[actualIndex];
                    final isSelected = item == widget.selectedItem;
                    final label = widget.labelBuilder(item);
                    final subtitle = widget.subtitleBuilder?.call(item);
                    final icon = widget.iconBuilder?.call(item);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context, item);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (icon != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon,
                                        size: 20,
                                        color: isSelected ? accentColor : Colors.white70),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected ? accentColor : Colors.white,
                                        ),
                                      ),
                                      if (subtitle != null)
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: accentColor, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
