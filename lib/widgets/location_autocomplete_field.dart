import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum LocationAutocompleteType { city, district }

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final LocationAutocompleteType type;
  final TextEditingController? cityController;
  final String labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final InputBorder? border;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.type,
    this.cityController,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.border,
    this.validator,
    this.textCapitalization = TextCapitalization.words,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<String>> _optionsBuilder(TextEditingValue textValue) async {
    final query = textValue.text.trim();
    if (widget.type == LocationAutocompleteType.city) {
      return ApiService.fetchLocationCities(query: query);
    }
    final city = widget.cityController?.text.trim() ?? '';
    return ApiService.fetchLocationDistricts(city: city, query: query);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: _optionsBuilder,
          onSelected: (selection) {
            widget.controller.text = selection;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: selection.length),
            );
          },
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              textCapitalization: widget.textCapitalization,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon,
                border: widget.border ?? const OutlineInputBorder(),
              ),
              validator: widget.validator,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey.shade100,
                    ),
                    itemBuilder: (context, index) {
                      final option = items[index];
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.type == LocationAutocompleteType.city
                                    ? Icons.location_city_rounded
                                    : Icons.place_outlined,
                                size: 17,
                                color: const Color(0xFF1BAA56),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
