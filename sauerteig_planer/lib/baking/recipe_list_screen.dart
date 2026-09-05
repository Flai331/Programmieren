import 'package:flutter/material.dart';
import 'baking_models.dart';
import 'recipe_storage.dart';
import 'recipe_edit_screen.dart';
import 'baking_screen.dart';
import '../app_colors.dart';
import '../fehlerbericht.dart';

// ═══════════════════════════════════════════════════════════════
//  REZEPTE-ÜBERSICHT
// ═══════════════════════════════════════════════════════════════

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  List<BakingRecipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await RecipeStorage.loadAll();
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
  }

  Future<void> _delete(BakingRecipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rezept löschen?',
            style: TextStyle(color: AppColors.text)),
        content: Text('„${recipe.name}" wird unwiderruflich gelöscht.',
            style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Löschen', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      await RecipeStorage.delete(recipe.id);
      _load();
    }
  }

  Future<void> _openEditor({BakingRecipe? recipe}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(recipe: recipe),
      ),
    );
    _load();
  }

  Future<void> _startBaking(BakingRecipe recipe) async {
    // lastUsed aktualisieren
    final updated = BakingRecipe(
      id: recipe.id,
      name: recipe.name,
      steps: recipe.steps,
      lastUsed: DateTime.now(),
    );
    await RecipeStorage.save(updated);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BakingScreen(recipe: updated)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title:
            const Text('⏱️ Backtimer', style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          // --- HIER DEN BUTTON EINFÜGEN ---
          IconButton(
            icon: const Icon(Icons.bug_report, color: AppColors.red),
            tooltip: 'Fehler melden',
            onPressed: () => Fehlerbericht.melden(context),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            tooltip: 'Neues Rezept',
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _recipes.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add),
        label: const Text('Neues Rezept'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍞', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Noch keine Backtimer',
            style: TextStyle(color: AppColors.text2, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Erstelle dein erstes Backrezept mit\nbeliebig vielen Schritten und Timern.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text3, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Erstes Rezept erstellen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recipes.length,
      itemBuilder: (_, i) {
        final r = _recipes[i];
        return _RecipeCard(
          recipe: r,
          onEdit: () => _openEditor(recipe: r),
          onDelete: () => _delete(r),
          onStart: () => _startBaking(r),
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final BakingRecipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStart;

  const _RecipeCard({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final stepCount = recipe.steps.length;
    final totalDuration = recipe.steps.fold(Duration.zero, (sum, s) {
      final stepTime = s.duration * s.repeatCount;
      final pauseTime = s.repeatCount > 1
          ? s.repeatInterval * (s.repeatCount - 1)
          : Duration.zero;
      return sum + stepTime + pauseTime;
    });

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.edit, color: AppColors.text3, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Bearbeiten',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.red, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Löschen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _chip('$stepCount Schritte'),
                const SizedBox(width: 8),
                _chip('${formatDuration(totalDuration)} gesamt'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Backen starten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.text2, fontSize: 12)),
    );
  }
}
