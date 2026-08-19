import 'package:flutter/material.dart';
import 'package:detool64/ui/click_tooltip.dart';
import 'package:detool64/logic/enchantment.dart';
import 'package:detool64/logic/equipment_type.dart';

class NewEnchantmentDialog extends StatefulWidget {
  final List<Enchantment> enchantments;
  final EquipmentType type;
  final void Function(Enchantment, int) onPressed;

  const NewEnchantmentDialog(
      {required this.enchantments,
      required this.type,
      required this.onPressed,
      super.key});

  @override
  State<NewEnchantmentDialog> createState() => _NewEnchantmentDialogState();
}

class _NewEnchantmentDialogState extends State<NewEnchantmentDialog> {
  int amountSliderValue = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text("Add an enchantment")),
      content: SizedBox(
        width: double.maxFinite,
        height: double.maxFinite,
        child: ListView(children: [
          Text("Amount: $amountSliderValue",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
          LayoutBuilder(
            builder: (ctx, constaints) {
              return Row(spacing: 0, children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      amountSliderValue = (amountSliderValue - 1).clamp(1, 100);
                    });
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(constaints.maxWidth * 0.15, 64)),
                  child: const Text("-",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
                ),
                SizedBox(
                  width: constaints.maxWidth * 0.7,
                  height: 64,
                  child: Slider(
                      min: 1,
                      max: 100,
                      value: amountSliderValue.toDouble(),
                      onChanged: (v) {
                        setState(() {
                          amountSliderValue = v.toInt();
                        });
                      }),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      amountSliderValue = (amountSliderValue + 1).clamp(1, 100);
                    });
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(constaints.maxWidth * 0.15, 64)),
                  child: const Text("+",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
                )
              ]);
            },
          ),
          ...EnchantmentsManager.groups
              .map((group) => [
                    Center(
                      child: Text(
                        group.displayName,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    ...EnchantmentsManager.enchantments
                        .where((e) =>
                            e.idFor(widget.type) != null && e.group == group)
                        .map((ench) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: FilledButton(
                                      onPressed: () => widget.onPressed(
                                          ench, amountSliderValue),
                                      child: Text(ench.name)),
                                ),
                                if (ench.description != null) ...[
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  ClickTooltip(
                                    message: ench.description,
                                    decoration: BoxDecoration(
                                        border: Border.all(width: 1),
                                        borderRadius: BorderRadius.circular(16),
                                        color: Theme.of(context).canvasColor),
                                    textStyle:
                                        Theme.of(context).textTheme.bodySmall,
                                    child: const Icon(Icons.info_outline),
                                  )
                                ]
                              ],
                            ))
                  ])
              .expand((e) => e)
        ]),
      ),
    );
  }
}
