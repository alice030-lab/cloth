import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../painting/art.dart';
import 'canvas_view.dart';
import 'import_editor.dart';
import 'panels.dart';
import 'rendering.dart';

class EditorPage extends StatefulWidget {
  final EditorController editor;
  const EditorPage({super.key, required this.editor});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  EditorController get e => widget.editor;
  int stage = 3, category = 0;
  bool busy = false;
  final captureKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!e.welcomed && mounted) {
        welcome();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      e.flush();
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> guarded(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      message('操作未完成，資料仍保留，請重試。');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> welcome() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: paper,
        title: const Text('買之前，先試搭。'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('讓想買的衣服，走進你的日常。'),
            SizedBox(height: 12),
            Text(
              '建立像自己的替身，貼上衣服、放進場景。照片與作品只留在這台裝置，不必登入。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text('先從貼一張星星痘痘貼開始。', style: TextStyle(color: wine, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'body'),
            child: const Text('建立我的替身'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'play'),
            child: const Text('先試玩'),
          ),
        ],
      ),
    );
    try {
      await e.welcome();
      await before();
      e.changed();
      if (mounted) {
        if (result == 'body') {
          bodyPanel();
        } else {
          setState(() => stage = 1);
        }
      }
    } catch (_) {
      message('偏好設定儲存失敗，可以繼續試玩。');
    }
  }

  Future<Uint8List> capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('畫布尚未準備好');
    }
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> before() async {
    if (e.doc.beforeAsset != null) {
      return;
    }
    final bytes = await renderBefore(e), id = 'before_${newId()}';
    await e.repo.putAsset(id, bytes);
    e.doc.beforeAsset = id;
  }

  Future<void> finish() async => guarded(() async {
    e.select(null);
    await before();
    final bytes = await capture(), id = 'after_${newId()}';
    await e.repo.putAsset(id, bytes);
    e.doc.afterAsset = id;
    e.changed();
    if (!await e.flush()) {
      throw StateError('儲存失敗');
    }
    if (!mounted) {
      return;
    }
    if (!MediaQuery.of(context).disableAnimations) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const RevealDialog(),
      );
    }
    if (mounted) {
      setState(() => stage = 4);
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ResultPage(editor: e, after: bytes),
        ),
      );
    }
  });
  Future<void> save() async => guarded(() async {
    await before();
    final bytes = await capture(), id = 'after_${newId()}';
    await e.repo.putAsset(id, bytes);
    e.doc.afterAsset = id;
    e.changed();
    await e.saveOutfit();
    message('作品已儲存，可在右上角作品集重新編輯。');
  });
  Future<void> importItem() async => guarded(() async {
    final file = await pickImage();
    if (file == null) {
      return;
    }
    if (await file.length() > 25 * 1024 * 1024) {
      message('圖片超過 25 MB，請先縮小再匯入。');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    final result = await Navigator.push<ImportedImage>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportEditor(bytes: bytes, filename: file.name),
      ),
    );
    if (result == null) {
      return;
    }
    final id = newId();
    final item = Item(
      id: id,
      name: result.name,
      kind: result.kind,
      assetId: 'item_$id',
      shape: 'import',
      aspect: result.aspect,
      sourceUrl: result.source,
    );
    await e.addImported(item, result.bytes);
    if (!mounted) {
      return;
    }
    final now = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已加入衣櫥'),
        content: Text('「${item.name}」已儲存於本機。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('繼續匯入'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即試穿'),
          ),
        ],
      ),
    );
    if (now == true) {
      e.add(item);
    } else if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          importItem();
        }
      });
    }
  });
  Future<void> bodyPanel() async {
    final b = await showModalBottomSheet<BodyProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BodyPanel(body: e.doc.body),
    );
    if (b != null) {
      e.body(b);
    }
  }

  Future<void> scenePanel() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScenePanel(editor: e),
    );
  }

  Future<void> projects() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ProjectsPage(editor: e)),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> layerMenu(CanvasLayer l) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.item(l.itemId).name, style: const TextStyle(fontSize: 18)),
            for (final entry in [
              ('最前', Icons.flip_to_front),
              ('最後', Icons.flip_to_back),
              ('貼回錨點', Icons.center_focus_strong),
              ('精確調整', Icons.tune),
              ('移除', Icons.delete_outline),
            ])
              ListTile(
                leading: Icon(entry.$2),
                title: Text(entry.$1),
                onTap: () => Navigator.pop(ctx, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (result == '精確調整' && mounted) {
      final value = await showModalBottomSheet<CanvasLayer>(
        context: context,
        showDragHandle: true,
        builder: (_) => LayerAdjustment(layer: l),
      );
      if (value != null) {
        e.change(() {
          l.x = value.x;
          l.y = value.y;
          l.scale = value.scale;
          l.rotation = value.rotation;
          l.snappedTo = null;
        });
      }
    }
    if (result == '最前') {
      e.reorder(l, true);
    }
    if (result == '最後') {
      e.reorder(l, false);
    }
    if (result == '移除') {
      e.remove(l.id);
    }
    if (result == '貼回錨點') {
      if (l.kind.anchor == null) {
        e.change(() {
          l.x = .5;
          l.y = .45;
        });
      } else {
        e.change(() => e.snap(l));
      }
    }
  }

  Future<void> layers() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: e,
        builder: (ctx, _) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('圖層', style: TextStyle(fontSize: 20)),
                if (e.doc.layers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('點選下方衣服，開始第一次試搭。'),
                  ),
                for (final l in e.doc.sorted.reversed)
                  ListTile(
                    selected: e.selected == l.id,
                    leading: SizedBox(
                      width: 36,
                      height: 40,
                      child: ItemArt(editor: e, item: e.item(l.itemId)),
                    ),
                    title: Text(e.item(l.itemId).name),
                    subtitle: Text(
                      '${l.kind.label} · ${l.snappedTo == null ? '自由位置' : '已吸附'}',
                    ),
                    onTap: () {
                      e.select(l.id);
                      Navigator.pop(ctx);
                    },
                    trailing: IconButton(
                      tooltip: '圖層選單',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () {
                        Navigator.pop(ctx);
                        layerMenu(l);
                      },
                    ),
                  ),
                const ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('L1 時裝畫替身'),
                  subtitle: Text('可在「我的替身」調整體型'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('你的照片，只留在這裡'),
              subtitle: Text(
                '這個版本不使用雲端帳號，也不會上傳照片。清除瀏覽器資料或移除 App 會移除本機作品，請先匯出。',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('開始新的變身'),
              onTap: () async {
                Navigator.pop(ctx);
                await guarded(() async {
                  await e.fresh();
                  await before();
                  e.changed();
                  setState(() => stage = 0);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('清除所有本機資料'),
              onTap: () async {
                Navigator.pop(ctx);
                final yes = await confirm(
                  context,
                  '清除所有本機資料？',
                  '作品、草稿、自訂圖片與體型資料會永久移除，請先匯出重要作品。',
                );
                if (yes) {
                  await guarded(e.clearAll);
                  message('本機資料已清除');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Item> get visible {
    final list = e.items.where((i) => !i.hidden);
    if (stage == 1) {
      return list.where((i) => i.kind == Kind.prop).toList();
    }
    if (stage == 2) {
      return list
          .where(
            (i) =>
                i.kind == Kind.hairFront ||
                i.kind == Kind.hairBack ||
                i.kind == Kind.accessory,
          )
          .toList();
    }
    return list
        .where(
          (i) => switch (category) {
            0 => i.kind == Kind.top || i.kind == Kind.outer,
            1 => i.kind == Kind.bottom,
            2 => i.kind == Kind.shoes || i.kind == Kind.accessory,
            3 => i.kind == Kind.prop || i.kind == Kind.reference,
            _ => false,
          },
        )
        .toList();
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '穿搭預演',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '買之前，先看看穿上的自己',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xff746660),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '作品集',
          onPressed: projects,
          icon: const Icon(Icons.bookmark_border_rounded),
        ),
        IconButton(
          tooltip: '隱私與設定',
          onPressed: settings,
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    ),
  );
  Widget _sceneRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: scenePanel,
              icon: const Icon(Icons.landscape_outlined, size: 18),
              label: Text(
                scenes.where((s) => s.id == e.doc.scene).firstOrNull?.name ??
                    '我的場景',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: bodyPanel,
          icon: const Icon(Icons.accessibility_new, size: 17),
          label: const Text('我的替身', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
  Widget _stages() => SizedBox(
    height: 48,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 5; i++)
          Flexible(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => stage = i);
                if (i == 4) {
                  scenePanel();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e.stageDone(i)
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: stage == i ? wine : const Color(0xffaa9589),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        const ['素顏', '保養', '整理', '穿搭', '登場'][i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: stage == i ? wine : const Color(0xff746660),
                          fontWeight: stage == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _tools() => Container(
    decoration: BoxDecoration(
      color: const Color(0xfffffcf8).withValues(alpha: .95),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: const Color(0xffeee4db)),
    ),
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: Column(
      children: [
        SizedBox(
          height: 40,
          child: stage == 1 || stage == 2 || stage == 0
              ? Row(
                  children: [
                    if (stage == 1 && !e.guideDone) const TutorialPointer(),
                    Expanded(
                      child: Text(
                        stage == 1
                            ? (e.guideDone ? '點一下貼紙，感受保養回饋' : '貼一張痘痘貼，照顧一下自己')
                            : stage == 2
                            ? '換個髮型，換個心情'
                            : '每次變身，從自己開始',
                        style: const TextStyle(fontSize: 12, color: wine),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        e.markGuided();
                        setState(() => stage = 3);
                      },
                      child: const Text('直接穿搭'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => category = i);
                            if (i == 4) {
                              scenePanel();
                            }
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: category == i
                                      ? wine
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              const ['上身', '下身', '鞋包', '道具', '場景'][i],
                              style: TextStyle(
                                fontSize: 13,
                                color: category == i ? wine : ink,
                                fontWeight: category == i
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visible.length + 2,
            separatorBuilder: (_, i) => const SizedBox(width: 10),
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return _importTile();
              }
              if (index == 1) {
                return _themeTile();
              }
              final it = visible[index - 2];
              return _itemTile(it);
            },
          ),
        ),
      ],
    ),
  );
  Widget _importTile() => SizedBox(
    width: 88,
    child: InkWell(
      onTap: busy ? null : importItem,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffbba397)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 27, color: wine),
            SizedBox(height: 7),
            Text('匯入截圖', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
  Widget _themeTile() => SizedBox(
    width: 88,
    child: InkWell(
      onTap: () async {
        if (await confirm(context, '套用週末咖啡廳主題？', '替換內建穿搭與髮型，自訂匯入的單品會保留。可復原。')) {
          e.theme();
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffeee3d7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 27, color: wine),
            SizedBox(height: 7),
            Text('咖啡廳主題', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
  Widget _itemTile(Item it) {
    final tile = SizedBox(
      width: 88,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 88,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffeee9e3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ItemArt(editor: e, item: it),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            it.name,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return LongPressDraggable<Item>(
      data: it,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 100,
          height: 120,
          child: ItemArt(editor: e, item: it),
        ),
      ),
      childWhenDragging: Opacity(opacity: .3, child: tile),
      child: GestureDetector(
        onTap: () => e.add(it),
        onSecondaryTap: () => manageItem(it),
        onDoubleTap: () => manageItem(it),
        child: tile,
      ),
    );
  }

  Future<void> manageItem(Item it) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(it.name), subtitle: Text(it.kind.label)),
            ListTile(
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await askName(context, '單品名稱', it.name);
                if (name != null) {
                  await guarded(() async {
                    await e.rename(it, name);
                  });
                }
              },
            ),
            ListTile(
              title: const Text('從衣櫥隱藏'),
              subtitle: const Text('不會破壞已儲存的作品'),
              onTap: () async {
                Navigator.pop(ctx);
                await guarded(() => e.hide(it));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottom() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        OutlinedButton(
          onPressed: busy ? null : save,
          style: OutlinedButton.styleFrom(minimumSize: const Size(52, 48)),
          child: const Icon(Icons.bookmark_border_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : finish,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              busy ? '正在處理…' : '完成穿搭',
              style: const TextStyle(fontSize: 16, letterSpacing: 2),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '管理衣櫥（單品雙擊也可管理）',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => WardrobePage(editor: e, onImport: importItem),
            ),
          ),
          icon: const Icon(Icons.checkroom_outlined),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: e,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (e.loadError != null)
              MaterialBanner(
                content: Text(e.loadError!),
                actions: [
                  TextButton(onPressed: settings, child: const Text('設定')),
                ],
              ),
            _header(),
            _sceneRow(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, b) {
                  final canvas = DragTarget<Item>(
                    onAcceptWithDetails: (d) {
                      final render =
                          captureKey.currentContext!.findRenderObject()
                              as RenderBox;
                      final local = render.globalToLocal(d.offset);
                      e.add(
                        d.data,
                        at: Offset(
                          (local.dx / render.size.width)
                              .clamp(.05, .95)
                              .toDouble(),
                          (local.dy / render.size.height)
                              .clamp(.05, .95)
                              .toDouble(),
                        ),
                      );
                    },
                    builder: (ctx, candidates, rejected) => CanvasView(
                      editor: e,
                      captureKey: captureKey,
                      onLayers: layers,
                      onMenu: layerMenu,
                    ),
                  );
                  final toolsHeight = b.maxHeight < 440 ? 148.0 : 174.0;
                  if (b.maxWidth > 760) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Expanded(child: canvas),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 320,
                            child: Column(
                              children: [
                                _stages(),
                                Expanded(child: _tools()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: canvas,
                        ),
                      ),
                      _stages(),
                      SizedBox(height: toolsHeight, child: _tools()),
                    ],
                  );
                },
              ),
            ),
            _bottom(),
            InkWell(
              onTap: () => e.flush(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${e.status} · 僅限本機',
                  style: TextStyle(
                    fontSize: 10,
                    color: e.status.startsWith('儲存失敗')
                        ? Colors.red
                        : const Color(0xff95867a),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RevealDialog extends StatefulWidget {
  const RevealDialog({super.key});
  @override
  State<RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<RevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )
        ..forward().whenComplete(() {
          if (mounted) {
            Navigator.pop(context);
          }
        });
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: paper,
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: FadeTransition(
        opacity: animation,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: wine),
            SizedBox(height: 20),
            Text('準備好，登場。', style: TextStyle(fontSize: 24, letterSpacing: 3)),
          ],
        ),
      ),
    ),
  );
}

class ResultPage extends StatefulWidget {
  final EditorController editor;
  final Uint8List after;
  const ResultPage({super.key, required this.editor, required this.after});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool busy = false;
  String? error;
  final cardKey = GlobalKey();
  late final TextEditingController name = TextEditingController(
    text: widget.editor.doc.name,
  );
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => error = '操作失敗，作品仍保留，請重試。');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> export(bool compare) async => act(() async {
    Uint8List bytes = widget.after;
    if (compare) {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
    }
    final filename = 'outfit_${DateTime.now().millisecondsSinceEpoch}';
    final saved = kIsWeb
        ? await FileSaver.instance.saveFile(
            name: filename,
            bytes: bytes,
            fileExtension: 'png',
            mimeType: MimeType.png,
          )
        : await FileSaver.instance.saveAs(
            name: filename,
            bytes: bytes,
            fileExtension: 'png',
            mimeType: MimeType.png,
          );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片已交給系統儲存')));
    }
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('這次，穿得很像自己。')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'YOUR MOMENT',
            style: TextStyle(fontSize: 11, letterSpacing: 3, color: wine),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: cardKey,
            child: Container(
              color: paper,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'BEFORE',
                              style: TextStyle(fontSize: 10, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            AspectRatio(
                              aspectRatio: 2 / 3,
                              child: widget.editor.doc.beforeAsset == null
                                  ? const ColoredBox(color: paper)
                                  : AssetImageView(
                                      editor: widget.editor,
                                      id: widget.editor.doc.beforeAsset!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'AFTER',
                              style: TextStyle(fontSize: 10, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            AspectRatio(
                              aspectRatio: 2 / 3,
                              child: Image.memory(
                                widget.after,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text(
                      '穿搭預演  /  買之前，先看看穿上的自己',
                      style: TextStyle(fontSize: 10, color: wine),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '作品名稱'),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => act(() async {
                    final title = name.text.trim();
                    if (title.isEmpty) {
                      throw const FormatException();
                    }
                    widget.editor.doc.name = title;
                    widget.editor.changed();
                    await widget.editor.saveOutfit();
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('作品已儲存')));
                    }
                  }),
            icon: const Icon(Icons.bookmark_border),
            label: const Text('儲存可編輯作品'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => export(false),
            icon: const Icon(Icons.download_outlined),
            label: const Text('匯出完成圖 PNG'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => export(true),
            icon: const Icon(Icons.compare_outlined),
            label: const Text('匯出前後對比卡'),
          ),
          if (!kIsWeb)
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => act(() async {
                      final box = context.findRenderObject() as RenderBox;
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [
                            XFile.fromData(widget.after, mimeType: 'image/png'),
                          ],
                          fileNameOverrides: ['穿搭預演.png'],
                          sharePositionOrigin:
                              box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    }),
              icon: const Icon(Icons.ios_share),
              label: const Text('分享完成圖'),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('繼續編輯'),
          ),
          const Text(
            '這是視覺試搭參考，不代表實際尺寸或布料合身度。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xff746660)),
          ),
        ],
      ),
    ),
  );
}

class TutorialPointer extends StatefulWidget {
  const TutorialPointer({super.key});
  @override
  State<TutorialPointer> createState() => _TutorialPointerState();
}

class _TutorialPointerState extends State<TutorialPointer>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      animation.stop();
      animation.value = .5;
    } else {
      animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '點擊或拖出下方痘痘貼',
    child: SizedBox(
      width: 34,
      height: 32,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: TutorialTrail(animation.value),
          child: Transform.translate(
            offset: Offset(0, animation.value * 6),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.touch_app_outlined, size: 20, color: wine),
            ),
          ),
        ),
      ),
    ),
  );
}

class TutorialTrail extends CustomPainter {
  final double progress;
  TutorialTrail(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(22 - i * 2, 3 + i * 4),
        Offset(21 - i * 2, 5 + i * 4),
        Paint()
          ..color = wine.withValues(alpha: .5)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(TutorialTrail old) => old.progress != progress;
}
