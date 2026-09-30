import 'package:flutter/material.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  DISCARD REZEPTE — skalierbar nach vorhandener Menge
// ═══════════════════════════════════════════════════════════════

class DiscardIngredient {
  final double baseAmount; // Menge bei baseDiscard g Discard
  final String unit; // 'g', 'ml', 'EL', 'TL', 'Ei', 'Stück', 'Prise'
  final String name;
  final bool scalable; // false = nicht skalieren (z.B. "1 Prise Salz")

  const DiscardIngredient({
    required this.baseAmount,
    required this.unit,
    required this.name,
    this.scalable = true,
  });
}

class DiscardRecipe {
  final String emoji;
  final String name;
  final int baseDiscard; // Basis-Discard-Menge in g
  final String description;
  final List<DiscardIngredient> ingredients;
  final List<String> steps;
  final String tip;

  const DiscardRecipe({
    required this.emoji,
    required this.name,
    required this.baseDiscard,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.tip,
  });
}

const kDiscardRecipes = <String, DiscardRecipe>{
  'Pfannkuchen': DiscardRecipe(
    emoji: '🥞',
    name: 'Sauerteig-Pfannkuchen',
    baseDiscard: 100,
    description: 'Fluffige Pfannkuchen mit leicht säuerlichem Aroma – '
        'das Frühstück-Highlight.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 1, unit: 'Ei', name: 'Ei'),
      DiscardIngredient(baseAmount: 100, unit: 'ml', name: 'Milch'),
      DiscardIngredient(baseAmount: 1, unit: 'EL', name: 'Zucker', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'Prise', name: 'Salz', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'EL', name: 'Butter zum Braten', scalable: false),
    ],
    steps: [
      'Überschuss (Discard),Ei und Milch gut verrühren.',
      'Salz und Zucker einrühren.',
      'Pfanne mit Butter bei mittlerer Hitze erhitzen.',
      'Pro Pfannkuchen ca. 2–3 EL Teig hineingeben.',
      'Ca. 2 Min. pro Seite goldbraun backen.',
    ],
    tip: 'Für fluffigere Pfannkuchen 1 TL Backpulver dazugeben.',
  ),

  'Waffeln': DiscardRecipe(
    emoji: '🧇',
    name: 'Sauerteig-Waffeln',
    baseDiscard: 100,
    description: 'Knusprige Waffeln mit tollem Geschmack – außen kross, innen weich.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 1, unit: 'Ei', name: 'Ei'),
      DiscardIngredient(baseAmount: 60, unit: 'ml', name: 'Milch'),
      DiscardIngredient(baseAmount: 30, unit: 'g', name: 'Butter (geschmolzen)'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Zucker', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'Prise', name: 'Salz', scalable: false),
    ],
    steps: [
      'Butter schmelzen und leicht abkühlen lassen.',
      'Überschuss (Discard),Ei, Milch und Butter verrühren.',
      'Zucker und Salz unterrühren.',
      'Waffeleisen vorheizen und einölen.',
      'Teig einfüllen und ca. 4–5 Min. backen bis goldbraun.',
    ],
    tip: 'Teig über Nacht im Kühlschrank lassen für noch mehr Aroma.',
  ),

  'Pizza-Teig': DiscardRecipe(
    emoji: '🍕',
    name: 'Sauerteig-Pizza',
    baseDiscard: 150,
    description: 'Knuspriger Pizza-Teig ohne zusätzliche Hefe – '
        'einfach und aromatisch.',
    ingredients: [
      DiscardIngredient(baseAmount: 150, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 200, unit: 'g', name: 'Mehl (Typ 550)'),
      DiscardIngredient(baseAmount: 80, unit: 'ml', name: 'Wasser'),
      DiscardIngredient(baseAmount: 2, unit: 'EL', name: 'Olivenöl', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Salz', scalable: false),
    ],
    steps: [
      'Alle Zutaten zu einem glatten Teig verkneten (ca. 8 Min.).',
      'Teig 1–2 Stunden bei Raumtemperatur ruhen lassen.',
      'Auf bemehlter Fläche dünn ausrollen.',
      'Mit Tomatensauce und Belag belegen.',
      'Im Ofen bei 230–250°C ca. 10–12 Min. backen.',
    ],
    tip: 'Je länger der Teig ruht, desto mehr Aroma entwickelt er.',
  ),

  'Kekse & Cracker': DiscardRecipe(
    emoji: '🍪',
    name: 'Sauerteig-Cracker',
    baseDiscard: 100,
    description: 'Knusprige Cracker für Käse, Dips oder einfach so.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 120, unit: 'g', name: 'Mehl'),
      DiscardIngredient(baseAmount: 2, unit: 'EL', name: 'Olivenöl'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Salz', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Kräuter nach Wahl', scalable: false),
    ],
    steps: [
      'Alle Zutaten zu einem Teig verkneten.',
      'Teig 30 Min. kalt stellen.',
      'Sehr dünn ausrollen (2–3 mm).',
      'In Rechtecke schneiden, mit Gabel einstechen.',
      'Bei 180°C ca. 15–18 Min. goldbraun backen.',
    ],
    tip: 'Sesam, Rosmarin oder Parmesan macht die Cracker besonders.',
  ),

  'Focaccia': DiscardRecipe(
    emoji: '🫓',
    name: 'Sauerteig-Focaccia',
    baseDiscard: 200,
    description: 'Fluffiges italienisches Fladenbrot mit Olivenöl und Kräutern.',
    ingredients: [
      DiscardIngredient(baseAmount: 200, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 250, unit: 'g', name: 'Mehl (Typ 550)'),
      DiscardIngredient(baseAmount: 150, unit: 'ml', name: 'Wasser'),
      DiscardIngredient(baseAmount: 4, unit: 'EL', name: 'Olivenöl'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Salz', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Rosmarin', scalable: false),
    ],
    steps: [
      'Überschuss (Discard),Wasser und Mehl verrühren.',
      'Salz und 2 EL Olivenöl unterkneten.',
      '2–3 Stunden bei Raumtemperatur gehen lassen.',
      'In ein geöltes Blech drücken, Grübchen eindrücken.',
      'Mit Olivenöl, Salz und Rosmarin bestreuen.',
      'Bei 220°C ca. 20–25 Min. backen.',
    ],
    tip: 'Tomaten, Oliven oder Zwiebeln als Belag machen sie besonders lecker.',
  ),

  'Bananenbrot': DiscardRecipe(
    emoji: '🍌',
    name: 'Sauerteig-Bananenbrot',
    baseDiscard: 100,
    description: 'Saftiges Bananenbrot mit leichter Säure – perfekt für überreife Bananen.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 2, unit: 'Stück', name: 'reife Bananen (~200g)'),
      DiscardIngredient(baseAmount: 150, unit: 'g', name: 'Mehl'),
      DiscardIngredient(baseAmount: 80, unit: 'g', name: 'Zucker'),
      DiscardIngredient(baseAmount: 1, unit: 'Ei', name: 'Ei'),
      DiscardIngredient(baseAmount: 60, unit: 'g', name: 'Butter (geschmolzen)'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Backpulver', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'Prise', name: 'Salz', scalable: false),
    ],
    steps: [
      'Backofen auf 175°C vorheizen, Kastenform einfetten.',
      'Bananen zerdrücken.',
      'Butter, Zucker und Ei schaumig rühren.',
      'Überschuss (Discard) und Bananen unterrühren.',
      'Mehl, Backpulver und Salz einrühren.',
      'In die Form füllen, ca. 55–60 Min. backen.',
      'Stäbchentest: trocken = fertig.',
    ],
    tip: 'Je reifer die Bananen, desto süßer und aromatischer.',
  ),

  'Tortillas': DiscardRecipe(
    emoji: '🌮',
    name: 'Sauerteig-Tortillas',
    baseDiscard: 100,
    description: 'Weiche Tortillas mit tollem Geschmack – für Tacos, Wraps & Co.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 150, unit: 'g', name: 'Mehl'),
      DiscardIngredient(baseAmount: 2, unit: 'EL', name: 'Öl'),
      DiscardIngredient(baseAmount: 50, unit: 'ml', name: 'Wasser'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Salz', scalable: false),
    ],
    steps: [
      'Alle Zutaten zu einem weichen Teig kneten.',
      '30 Min. ruhen lassen.',
      'In 6–8 Portionen teilen und dünn ausrollen.',
      'In einer trockenen heißen Pfanne je 1–2 Min. pro Seite backen.',
      'Zwischen einem Küchentuch warm halten.',
    ],
    tip: 'Teig dünn ausrollen – je dünner, desto weicher die Tortilla.',
  ),

  'Soße andicken': DiscardRecipe(
    emoji: '🍲',
    name: 'Soße andicken mit Überschuss (Discard)',
    baseDiscard: 50,
    description: 'Überschuss (Discard) als natürlicher Saucen-Verdicker – '
        'gibt Tiefe und Umami-Aroma.',
    ingredients: [
      DiscardIngredient(baseAmount: 50, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 200, unit: 'ml', name: 'Soße/Suppe'),
    ],
    steps: [
      'Überschuss (Discard) in die heiße (nicht kochende) Soße einrühren.',
      'Bei mittlerer Hitze 2–3 Min. köcheln lassen.',
      'Nach Bedarf mehr Überschuss (Discard) für dickere Konsistenz zugeben.',
      'Abschmecken.',
    ],
    tip: 'Gut geeignet für Bratensauce, Tomatensuppe oder Eintöpfe.',
  ),

  'Muffins': DiscardRecipe(
    emoji: '🧁',
    name: 'Sauerteig-Muffins',
    baseDiscard: 100,
    description: 'Saftige Muffins – schnell gemacht und vielseitig belegbar.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 150, unit: 'g', name: 'Mehl'),
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Zucker'),
      DiscardIngredient(baseAmount: 1, unit: 'Ei', name: 'Ei'),
      DiscardIngredient(baseAmount: 60, unit: 'ml', name: 'Öl'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Backpulver', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'Prise', name: 'Salz', scalable: false),
    ],
    steps: [
      'Backofen auf 180°C vorheizen, Muffinform einfetten.',
      'Überschuss (Discard),Ei und Öl verrühren.',
      'Trockene Zutaten unterheben – nicht zu lange rühren!',
      'Teig in die Form füllen (¾ voll).',
      'Ca. 20–22 Min. backen.',
    ],
    tip: 'Blaubeeren, Schokostücke oder Nüsse machen die Muffins besonders.',
  ),

  'Nudelteig': DiscardRecipe(
    emoji: '🍜',
    name: 'Sauerteig-Nudelteig',
    baseDiscard: 100,
    description: 'Frische Pasta mit besonderem Geschmack – überraschend einfach.',
    ingredients: [
      DiscardIngredient(baseAmount: 100, unit: 'g', name: 'Sauerteig-Überschuss (Discard)'),
      DiscardIngredient(baseAmount: 200, unit: 'g', name: 'Mehl (Tipo 00 oder 405)'),
      DiscardIngredient(baseAmount: 2, unit: 'Ei', name: 'Eier'),
      DiscardIngredient(baseAmount: 1, unit: 'TL', name: 'Salz', scalable: false),
      DiscardIngredient(baseAmount: 1, unit: 'EL', name: 'Olivenöl', scalable: false),
    ],
    steps: [
      'Alle Zutaten zu einem glatten Teig kneten (ca. 10 Min.).',
      'In Folie wickeln, 30 Min. ruhen lassen.',
      'Dünn ausrollen oder durch die Nudelmaschine drehen.',
      'In gewünschte Form schneiden.',
      'In Salzwasser 2–3 Min. kochen.',
    ],
    tip: 'Teig 1h im Kühlschrank lagern macht ihn noch geschmeidiger.',
  ),
};

// ── Discard-Rezept Bottom Sheet ─────────────────────────────────

void showDiscardRecipe(BuildContext context, String name, int discardAmount) {
  final recipe = kDiscardRecipes[name];
  if (recipe == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DiscardRecipeSheet(recipe: recipe, initialAmount: discardAmount),
  );
}

class _DiscardRecipeSheet extends StatefulWidget {
  final DiscardRecipe recipe;
  final int initialAmount;
  const _DiscardRecipeSheet({required this.recipe, required this.initialAmount});

  @override
  State<_DiscardRecipeSheet> createState() => _DiscardRecipeSheetState();
}

class _DiscardRecipeSheetState extends State<_DiscardRecipeSheet> {
  late int _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount.clamp(10, 9999);
  }

  void _adjust(int delta) {
    setState(() => _amount = (_amount + delta).clamp(10, 9999));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final scale = _amount / recipe.baseDiscard;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Griff-Balken
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titel
          Row(children: [
            Text(recipe.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.name,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(recipe.description,
                    style: const TextStyle(
                        color: AppColors.text2, fontSize: 12, height: 1.4)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),

          // Menge (anpassbar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.kitchen, color: AppColors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Überschuss (Discard): $_amount g',
                  style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              _AdjustBtn(icon: Icons.remove, onTap: () => _adjust(-10)),
              const SizedBox(width: 4),
              _AdjustBtn(icon: Icons.add, onTap: () => _adjust(10)),
            ]),
          ),
          const SizedBox(height: 16),

          // Zutaten
          const Text('ZUTATEN',
              style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
          const SizedBox(height: 8),
          ...recipe.ingredients.map((ing) {
            final amount = ing.scalable ? ing.baseAmount * scale : ing.baseAmount;
            final amountStr = _formatAmount(amount, ing.unit);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text('$amountStr ${ing.unit}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ing.name,
                      style: const TextStyle(
                          color: AppColors.text2, fontSize: 13)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // Zubereitung
          const Text('ZUBEREITUNG',
              style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
          const SizedBox(height: 8),
          ...recipe.steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text('${e.key + 1}',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            color: AppColors.text2,
                            fontSize: 13,
                            height: 1.4)),
                  ),
                ]),
              )),
          const SizedBox(height: 12),

          // Tipp
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1400),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(recipe.tip,
                    style: const TextStyle(
                        color: AppColors.text2,
                        fontSize: 12,
                        height: 1.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _AdjustBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AdjustBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 16, color: AppColors.green),
      ),
    );
  }
}

String _formatAmount(double amount, String unit) {
  if (unit == 'Ei' || unit == 'Stück') {
    final rounded = amount.round();
    if (rounded == 0 && amount > 0) return '½';
    return '$rounded';
  }
  if (unit == 'EL' || unit == 'TL' || unit == 'Prise') {
    return amount.toStringAsFixed(0);
  }
  if (amount < 10) return amount.toStringAsFixed(0);
  return (amount.round()).toString();
}
