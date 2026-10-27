import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/images.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../painting/art.dart';
import 'canvas_view.dart';
import 'import_editor.dart';

Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認'),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> askName(
  BuildContext context,
  String title,
  String initial,
) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.pop(ctx, value);
            }
          },
          child: const Text('儲存'),
        ),
      ],
    ),
  );
  // Dialog route exit animation may still hold its TextField for one frame.
  Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
  return result;
}

class BodyPanel extends StatefulWidget {
  final BodyProfile body;
  const BodyPanel({super.key, required this.body});
  @override
  State<BodyPanel> createState() => _BodyPanelState();
}

class _BodyPanelState extends State<BodyPanel> {
  late final BodyProfile body = widget.body.copy();
  late final fields = {
    for (final key in BodyProfile.ranges.keys)
      key: TextEditingController(text: body.get(key).round().toString()),
  };
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .92,
    child: Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: '取消',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('我的替身'),
        actions: [
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, body);
              }
            },
            child: const Text('套用'),
          ),
        ],
      ),
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: 100,
                  height: 230,
                  child: CustomPaint(painter: AvatarPainter(body)),
                ),
              ),
              const Center(
                child: Text(
                  'L1 時裝畫 · 身材比例預覽',
                  style: TextStyle(fontSize: 12, color: wine),
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: body.gender,
                decoration: const InputDecoration(labelText: '性別表現'),
                items: const [
                  DropdownMenuItem(
                    value: 'feminine',
                    child: Text('柔和 Feminine'),
                  ),
                  DropdownMenuItem(
                    value: 'masculine',
                    child: Text('俐落 Masculine'),
                  ),
                  DropdownMenuItem(value: 'neutral', child: Text('中性 Neutral')),
                ],
                onChanged: (v) => setState(() => body.gender = v!),
              ),
              const SizedBox(height: 12),
              for (final entry in [
                ('height', '身高'),
                ('bust', '胸圍'),
                ('waist', '腰圍'),
                ('hip', '臀圍'),
                ('shoulder', '肩寬（選填）'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 82,
                        child: Text(
                          entry.$2,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: body
                              .get(entry.$1)
                              .clamp(
                                BodyProfile.ranges[entry.$1]!.$1,
                                BodyProfile.ranges[entry.$1]!.$2,
                              )
                              .toDouble(),
                          min: BodyProfile.ranges[entry.$1]!.$1,
                          max: BodyProfile.ranges[entry.$1]!.$2,
                          onChanged: (v) => setState(() {
                            body.set(entry.$1, v);
                            fields[entry.$1]!.text = v.round().toString();
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 78,
                        child: TextFormField(
                          controller: fields[entry.$1],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'cm',
                            contentPadding: EdgeInsets.all(8),
                          ),
                          validator: (text) {
                            final v = double.tryParse(text ?? '');
                            final r = BodyProfile.ranges[entry.$1]!;
                            return v == null ||
                                    !v.isFinite ||
                                    v < r.$1 ||
                                    v > r.$2
                                ? '${r.$1.round()}–${r.$2.round()}'
                                : null;
                          },
                          onChanged: (text) {
                            final v = double.tryParse(text),
                                r = BodyProfile.ranges[entry.$1]!;
                            if (v != null &&
                                v.isFinite &&
                                v >= r.$1 &&
                                v <= r.$2) {
                              setState(() => body.set(entry.$1, v));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text('膚色'),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 8; i++)
                    Semantics(
                      label: '膚色 ${i + 1}',
                      selected: body.skin == i,
                      button: true,
                      child: InkWell(
                        onTap: () => setState(() => body.skin = i),
                        child: Container(
                          width: 32,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const [
                              Color(0xfff7dcc6),
                              Color(0xffeac4a6),
                              Color(0xffd9ae8d),
                              Color(0xffc49170),
                              Color(0xffac7959),
                              Color(0xff936044),
                              Color(0xff744932),
                              Color(0xff513428),
                            ][i],
                            border: Border.all(
                              color: body.skin == i ? wine : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: body.face,
                decoration: const InputDecoration(labelText: '臉型（選填）'),
                items: const [
                  DropdownMenuItem(value: '柔和', child: Text('柔和')),
                  DropdownMenuItem(value: '俐落', child: Text('俐落')),
                ],
                onChanged: (v) => setState(() => body.face = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                '數值只用於插畫比例，不是尺寸／合身預測。超出目前模型支援範圍時會提示，不會默默更改。',
                style: TextStyle(fontSize: 12, color: Color(0xff746660)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ScenePanel extends StatefulWidget {
  final EditorController editor;
  const ScenePanel({super.key, required this.editor});
  @override
  State<ScenePanel> createState() => _ScenePanelState();
}

class _ScenePanelState extends State<ScenePanel> {
  late String scene = widget.editor.doc.scene;
  late double x = widget.editor.doc.cropX, y = widget.editor.doc.cropY;
  bool busy = false;
  String? custom;
  Future<void> import() async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      final file = await pickImage();
      if (file == null) {
        return;
      }
      if (await file.length() > 25 * 1024 * 1024) {
        throw const FormatException();
      }
      final bytes = await file.readAsBytes();
      // Decode before committing the asset, then store normalized PNG.
      final image = await decodeBounded(bytes);
      final normalized = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      final id = 'scene_${newId()}';
      await widget.editor.repo.putAsset(id, normalized);
      if (mounted) {
        setState(() {
          scene = id;
          custom = id;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('場景圖片讀取失敗，請選擇 25 MB 以下的 JPEG／PNG。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget preview() {
    final e = widget.editor;
    if (scene.startsWith('scene_')) {
      return AssetImageView(
        editor: e,
        id: scene,
        fit: BoxFit.cover,
        alignment: Alignment(x, y),
      );
    }
    if (scene == 'cafe') {
      return Image.asset(
        'assets/scenes/cafe.png',
        fit: BoxFit.cover,
        alignment: Alignment(x, y),
      );
    }
    return CustomPaint(
      painter: ScenePainter(scene, cropX: x, cropY: y),
    );
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .85,
    child: Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '取消',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('選一個想去的地方'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () {
                    widget.editor.scene(scene, x: x, y: y);
                    Navigator.pop(context);
                  },
            child: const Text('套用'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 210,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: preview(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in scenes)
                ChoiceChip(
                  label: Text(s.name),
                  selected: scene == s.id,
                  onSelected: (_) => setState(() => scene = s.id),
                ),
              if (custom != null)
                ChoiceChip(
                  label: const Text('我的場景'),
                  selected: scene == custom,
                  onSelected: (_) => setState(() => scene = custom!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : import,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(busy ? '正在讀取…' : '從相簿／檔案加入場景'),
          ),
          const SizedBox(height: 12),
          const Text('調整取景'),
          Row(
            children: [
              const Text('水平'),
              Expanded(
                child: Slider(
                  value: x,
                  min: -1,
                  max: 1,
                  onChanged: (v) => setState(() => x = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('垂直'),
              Expanded(
                child: Slider(
                  value: y,
                  min: -1,
                  max: 1,
                  onChanged: (v) => setState(() => y = v),
                ),
              ),
            ],
          ),
          const Text(
            '切換場景會保留你已搭好的服裝。',
            style: TextStyle(fontSize: 12, color: Color(0xff746660)),
          ),
        ],
      ),
    ),
  );
}

class ProjectsPage extends StatefulWidget {
  final EditorController editor;
  const ProjectsPage({super.key, required this.editor});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late Future<List<CanvasDocument>> future = widget.editor.repo.outfits();
  bool busy = false;
  void reload() => setState(() => future = widget.editor.repo.outfits());
  Future<void> action(Future<void> Function() task) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await task();
      reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('作品操作失敗，原資料仍保留，請重試。')));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的穿搭作品')),
    body: FutureBuilder<List<CanvasDocument>>(
      future: future,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('作品暫時無法讀取，資料未刪除。'),
                TextButton(onPressed: reload, child: const Text('重試')),
              ],
            ),
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_border, size: 48, color: wine),
                SizedBox(height: 16),
                Text('還沒有作品，先完成一次穿搭吧。'),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            childAspectRatio: .56,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: s.data!.length,
          itemBuilder: (context, i) {
            final d = s.data![i];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () => action(() async {
                              if (!await widget.editor.flush()) {
                                throw StateError('儲存失敗');
                              }
                              widget.editor.open(d);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }),
                      child: SizedBox.expand(
                        child: d.afterAsset == null
                            ? const Center(child: Icon(Icons.checkroom))
                            : AssetImageView(
                                editor: widget.editor,
                                id: d.afterAsset!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '${d.updatedAt.month}/${d.updatedAt.day} · 本機作品',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xff746660),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !busy,
                          tooltip: '作品選單',
                          onSelected: (value) => action(() async {
                            if (value == 'duplicate') {
                              widget.editor.duplicate(d);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } else if (value == 'rename') {
                              final name = await askName(
                                context,
                                '作品名稱',
                                d.name,
                              );
                              if (name != null) {
                                d.name = name;
                                await widget.editor.repo.saveOutfit(d);
                                if (widget.editor.doc.id == d.id) {
                                  widget.editor.doc.name = name;
                                  widget.editor.changed();
                                }
                              }
                            } else if (await confirm(
                              context,
                              '刪除作品？',
                              '已匯出的圖片不受影響。',
                            )) {
                              await widget.editor.repo.deleteOutfit(d.id);
                            }
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'duplicate',
                              child: Text('複製為新變身'),
                            ),
                            PopupMenuItem(value: 'rename', child: Text('重新命名')),
                            PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class WardrobePage extends StatefulWidget {
  final EditorController editor;
  final Future<void> Function() onImport;
  const WardrobePage({super.key, required this.editor, required this.onImport});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  Kind? filter;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.editor,
    builder: (context, _) {
      final e = widget.editor;
      final items =
          e.items
              .where((i) => !i.hidden && (filter == null || i.kind == filter))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的衣櫥'),
          actions: [
            IconButton(
              tooltip: '匯入截圖',
              onPressed: () {
                Navigator.pop(context);
                widget.onImport();
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('全部'),
                      selected: filter == null,
                      onSelected: (_) => setState(() => filter = null),
                    ),
                  ),
                  for (final k in Kind.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(k.label),
                        selected: filter == k,
                        onSelected: (_) => setState(() => filter = k),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('這個分類還沒有單品，試試匯入截圖。'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: .75,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return Card(
                          child: Column(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    e.add(it);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: SizedBox.expand(
                                      child: ItemArt(editor: e, item: it),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        it.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: '單品選單',
                                    onSelected: (value) async {
                                      try {
                                        if (value == 'rename') {
                                          final name = await askName(
                                            context,
                                            '單品名稱',
                                            it.name,
                                          );
                                          if (name != null) {
                                            await e.rename(it, name);
                                          }
                                        } else if (await confirm(
                                          context,
                                          '從衣櫥移除？',
                                          '現有作品仍會保留這個素材。',
                                        )) {
                                          await e.hide(it);
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('操作失敗，請重試。'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text('重新命名'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('移除'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class LayerAdjustment extends StatefulWidget {
  final CanvasLayer layer;
  const LayerAdjustment({super.key, required this.layer});
  @override
  State<LayerAdjustment> createState() => _LayerAdjustmentState();
}

class _LayerAdjustmentState extends State<LayerAdjustment> {
  late final CanvasLayer value = widget.layer.copy();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('精確調整', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          for (final entry in [
            ('水平位置', value.x, 0.02, 0.98),
            ('垂直位置', value.y, 0.02, 0.96),
            ('大小', value.scale, 0.03, 2.0),
            (
              '旋轉',
              value.rotation.clamp(-3.14159, 3.14159).toDouble(),
              -3.14159,
              3.14159,
            ),
          ])
            Row(
              children: [
                SizedBox(width: 70, child: Text(entry.$1)),
                Expanded(
                  child: Slider(
                    value: entry.$2.clamp(entry.$3, entry.$4).toDouble(),
                    min: entry.$3,
                    max: entry.$4,
                    onChanged: (v) => setState(() {
                      switch (entry.$1) {
                        case '水平位置':
                          value.x = v;
                        case '垂直位置':
                          value.y = v;
                        case '大小':
                          value.scale = v;
                        case '旋轉':
                          value.rotation = v;
                      }
                    }),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, value),
                  child: const Text('套用'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
