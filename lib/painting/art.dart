import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../core/models.dart';

const ink = Color(0xff292321),
    wine = Color(0xff762e3d),
    paper = Color(0xfff8f3ee);

class Art {
  final Canvas c;
  Art(this.c);
  void path(List<double> pts, Color color, {Color? stroke, double width = 1}) {
    final p = Path()..moveTo(pts[0], pts[1]);
    var i = 2;
    for (; i + 5 < pts.length; i += 6) {
      p.cubicTo(
        pts[i],
        pts[i + 1],
        pts[i + 2],
        pts[i + 3],
        pts[i + 4],
        pts[i + 5],
      );
    }
    for (; i + 1 < pts.length; i += 2) {
      p.lineTo(pts[i], pts[i + 1]);
    }
    p.close();
    c.drawPath(p, Paint()..color = color);
    if (stroke != null) {
      c.drawPath(
        p,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void line(List<Offset> pts, Color color, {double width = 1}) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(
      p,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void oval(Rect r, Color color) => c.drawOval(r, Paint()..color = color);
  void rect(Rect r, Color color, {double radius = 0}) => c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    Paint()..color = color,
  );
}

class AvatarPainter extends CustomPainter {
  final BodyProfile body;
  AvatarPainter(this.body);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 720);
    final a = Art(canvas), g = FigureGeometry(body);
    final skin = const [
      Color(0xfff7dcc6),
      Color(0xffeac4a6),
      Color(0xffd9ae8d),
      Color(0xffc49170),
      Color(0xffac7959),
      Color(0xff936044),
      Color(0xff744932),
      Color(0xff513428),
    ][body.skin];
    final shadow = Color.lerp(skin, const Color(0xff7a4436), .19)!;
    final s = g.shoulder, b = g.chest, w = g.waist, h = g.hip, e = g.legEnd;
    void shape(String data, Color fill, {Color? stroke, double width = .8}) {
      final path = parseSvgPathData(data);
      canvas.drawPath(path, Paint()..color = fill);
      if (stroke != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    void line(String data, Color color, {double width = 1}) => canvas.drawPath(
      parseSvgPathData(data),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    a.oval(
      Rect.fromCenter(center: Offset(150, e + 30), width: 126, height: 12),
      const Color(0x18000000),
    );
    // Rear hair, legs and hands are separate shapes. Parameter edits move their
    // own control points rather than stretching a complete character bitmap.
    shape(
      'M139 27 Q101 18 109 92 Q95 147 94 181 Q150 199 196 177 Q183 134 185 77 Q190 20 151 25 Z',
      const Color(0xff392f2b),
    );
    shape(
      'M${150 - h} 306 C${145 - h} 367 102 449 108 497 C110 547 108 ${e - 30} 109 $e L99 ${e + 18} Q95 ${e + 27} 109 ${e + 27} Q124 ${e + 26} 132 ${e + 17} L128 ${e - 2} C128 575 135 536 136 499 C140 453 150 387 149 342 Z',
      skin,
      stroke: shadow.withValues(alpha: .5),
    );
    shape(
      'M${150 + h} 306 C${155 + h} 367 195 449 189 497 C183 550 181 ${e - 28} 182 $e L199 ${e + 19} Q205 ${e + 29} 191 ${e + 29} Q174 ${e + 27} 166 ${e + 17} L169 ${e - 2} C165 574 158 537 159 499 C156 451 149 387 151 342 Z',
      skin,
      stroke: shadow.withValues(alpha: .5),
    );
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(300, 0);
        canvas.scale(-1, 1);
      }
      shape(
        'M${150 - s} 150 Q${130 - s} 145 ${128 - s} 209 L${113 - s} 322 Q${106 - s} 347 ${119 - s} 375 L${126 - s} 380 L${126 - s} 363 L${134 - s} 377 L${139 - s} 374 L${132 - s} 346 L${139 - s} 300 L${160 - s} 194 Z',
        skin,
        stroke: shadow.withValues(alpha: .4),
      );
      line(
        'M${133 - s} 204 L${124 - s} 285 L${122 - s} 319',
        shadow,
        width: .7,
      );
      canvas.restore();
    }
    shape(
      'M139 103 L140 131 Q132 143 ${150 - s} 150 Q${146 - s} 175 ${150 - b} 204 Q${150 - b} 233 ${150 - w} 270 Q${150 - w} 290 ${150 - h} 315 Q${150 - h} 342 150 348 Q${150 + h} 342 ${150 + h} 315 Q${150 + w} 290 ${150 + w} 270 Q${150 + b} 233 ${150 + b} 204 Q${154 + s} 175 ${150 + s} 150 Q168 143 160 131 L161 103 Z',
      skin,
      stroke: shadow.withValues(alpha: .35),
    );
    shape('M139 111 Q150 123 160 111 L160 129 Q151 144 139 134 Z', shadow);
    line(
      'M${162 - s} 157 L137 150 L148 156 L162 150 L${138 + s} 157',
      shadow,
      width: .8,
    );
    // The modest base is a continuous camisole, not intersecting triangles.
    shape(
      'M127 148 Q150 171 173 148 Q${158 + b} 177 ${148 + b} 207 Q${149 + b} 237 ${150 + w} 272 Q150 282 ${150 - w} 272 Q${151 - b} 237 ${152 - b} 207 Q${142 - b} 177 127 148 Z',
      const Color(0xffe7d5c5),
      stroke: const Color(0xffc5a995),
    );
    shape(
      'M${152 - h} 303 Q150 318 ${148 + h} 303 Q172 326 162 343 L138 343 Q128 326 ${152 - h} 303 Z',
      const Color(0xffe7d5c5),
      stroke: const Color(0xffc5a995),
    );
    line(
      'M115 489 Q121 496 130 490 M165 490 Q174 496 183 488',
      shadow,
      width: .8,
    );
    a.oval(const Rect.fromLTWH(122, 65, 10, 20), shadow);
    a.oval(const Rect.fromLTWH(169, 65, 10, 20), shadow);
    final chin = body.face == '俐落' ? 109 : 113;
    shape(
      'M128 52 Q133 32 151 34 Q180 34 174 73 Q172 99 150 $chin Q124 101 126 70 Z',
      skin,
      stroke: shadow,
      width: .6,
    );
    a.oval(
      const Rect.fromLTWH(129, 80, 14, 6),
      Color.lerp(skin, const Color(0xffd17b79), .27)!,
    );
    a.oval(
      const Rect.fromLTWH(158, 80, 14, 6),
      Color.lerp(skin, const Color(0xffd17b79), .27)!,
    );
    line(
      'M132 64 L138 62 L143 64 M157 64 L162 62 L168 64',
      const Color(0xff675147),
      width: 1.6,
    );
    line(
      'M132 72 Q138 68 143 72 M157 72 Q162 68 168 71',
      const Color(0xff3d332f),
      width: 1.1,
    );
    a.oval(const Rect.fromLTWH(137, 70, 3, 4), const Color(0xff302b27));
    a.oval(const Rect.fromLTWH(160, 70, 3, 4), const Color(0xff302b27));
    line('M150 73 L147 84 L152 85', shadow, width: .8);
    shape(
      'M142 94 Q147 91 150 94 Q154 91 158 94 Q150 101 142 94 Z',
      const Color(0xffa86c66),
    );
    line('M145 94 H155', const Color(0xff89524e), width: .65);
    shape(
      'M124 72 Q115 51 128 32 Q143 22 154 28 Q182 24 178 61 L166 43 Q153 59 132 58 L125 107 L117 128 Q110 111 124 72 Z M165 43 Q182 59 172 86 Q168 110 185 131 L181 146 Q161 127 166 97 Z',
      const Color(0xff392f2b),
    );
    line(
      'M139 34 Q126 43 125 59 M146 32 Q134 43 131 56 M174 79 Q174 115 181 127',
      const Color(0xff6a5142),
      width: .8,
    );
    a.oval(const Rect.fromLTWH(123, 83, 3, 5), const Color(0xffd8b873));
    a.oval(const Rect.fromLTWH(173, 83, 3, 5), const Color(0xffd8b873));
    canvas.restore();
  }

  @override
  bool shouldRepaint(AvatarPainter old) => true;
}

class ItemPainter extends CustomPainter {
  final Item item;
  final bool activated;
  ItemPainter(this.item, {this.activated = false});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final a = Art(canvas);
    final color = Color(item.color),
        edge = Color.lerp(Color(item.color), ink, .22)!;
    void seam(List<Offset> p, {double width = .65}) =>
        a.line(p, edge, width: width);
    switch (item.shape) {
      case 'tee':
      case 'blouse':
        a.path(
          [
            35,
            5,
            38,
            15,
            62,
            15,
            65,
            5,
            73,
            8,
            84,
            12,
            96,
            26,
            93,
            33,
            88,
            42,
            78,
            39,
            77,
            59,
            78,
            80,
            81,
            94,
            64,
            99,
            36,
            99,
            19,
            94,
            22,
            77,
            23,
            55,
            22,
            39,
            14,
            42,
            7,
            34,
            4,
            26,
            16,
            13,
            27,
            8,
            35,
            5,
          ],
          color,
          stroke: edge,
          width: .7,
        );
        seam([
          const Offset(35, 5),
          const Offset(37, 15),
          const Offset(50, 19),
          const Offset(63, 15),
          const Offset(65, 5),
        ]);
        seam([const Offset(23, 37), const Offset(26, 27)]);
        seam([const Offset(77, 37), const Offset(74, 27)]);
        seam([
          const Offset(24, 91),
          const Offset(50, 94),
          const Offset(77, 91),
        ]);
        if (item.shape == 'blouse') {
          seam([const Offset(50, 19), const Offset(50, 92)]);
          for (var y = 30.0; y < 90; y += 12) {
            a.oval(Rect.fromLTWH(48, y, 2, 2), edge);
          }
          a.path([
            50,
            20,
            38,
            12,
            37,
            27,
            48,
            23,
            42,
            39,
            50,
            30,
            50,
            20,
          ], edge);
          a.path([
            50,
            20,
            63,
            12,
            63,
            27,
            52,
            23,
            58,
            39,
            50,
            30,
            50,
            20,
          ], edge);
        }
        break;
      case 'cardigan':
        a.path(
          [
            36,
            3,
            37,
            16,
            44,
            34,
            47,
            99,
            25,
            99,
            24,
            57,
            18,
            88,
            4,
            85,
            12,
            42,
            21,
            14,
            36,
            3,
          ],
          color,
          stroke: edge,
        );
        a.path(
          [
            64,
            3,
            63,
            16,
            56,
            34,
            53,
            99,
            75,
            99,
            76,
            57,
            82,
            88,
            96,
            85,
            88,
            42,
            79,
            14,
            64,
            3,
          ],
          color,
          stroke: edge,
        );
        seam([
          const Offset(36, 3),
          const Offset(42, 36),
          const Offset(47, 99),
        ], width: 1.2);
        seam([
          const Offset(64, 3),
          const Offset(58, 36),
          const Offset(53, 99),
        ], width: 1.2);
        for (var y = 40.0; y < 95; y += 13) {
          a.oval(Rect.fromLTWH(55, y, 2.7, 2), const Color(0xffddccb2));
        }
        for (var x = 28.0; x < 45; x += 4) {
          seam([Offset(x, 51), Offset(x, 97)], width: .3);
        }
        for (var x = 60.0; x < 74; x += 4) {
          seam([Offset(x, 51), Offset(x, 97)], width: .3);
        }
        break;
      case 'jeans':
      case 'trousers':
        a.path(
          [
            7,
            1,
            27,
            4,
            72,
            4,
            93,
            1,
            99,
            19,
            97,
            42,
            95,
            57,
            93,
            70,
            95,
            91,
            94,
            99,
            79,
            100,
            65,
            100,
            58,
            97,
            56,
            81,
            54,
            62,
            50,
            35,
            46,
            62,
            44,
            81,
            42,
            97,
            35,
            100,
            20,
            100,
            6,
            99,
            5,
            90,
            7,
            70,
            5,
            57,
            3,
            42,
            1,
            19,
            7,
            1,
          ],
          color,
          stroke: edge,
          width: .9,
        );
        seam([const Offset(7, 9), const Offset(93, 9)], width: 1.1);
        seam([const Offset(50, 9), const Offset(52, 28), const Offset(48, 34)]);
        seam([const Offset(9, 11), const Offset(18, 22), const Offset(32, 23)]);
        seam([
          const Offset(91, 11),
          const Offset(82, 22),
          const Offset(68, 23),
        ]);
        seam([const Offset(26, 31), const Offset(24, 97)], width: .6);
        seam([const Offset(75, 31), const Offset(77, 97)], width: .6);
        a.oval(const Rect.fromLTWH(47, 5, 4, 2), const Color(0xffc9b385));
        for (final x in [18.0, 36.0, 65.0, 83.0]) {
          a.rect(Rect.fromLTWH(x, 2, 2, 8), edge);
        }
        if (item.shape == 'jeans') {
          for (var y = 35.0; y < 93; y += 3) {
            a.line(
              [Offset(9, y), Offset(21, y + 1)],
              const Color(0x188fa5b3),
              width: .4,
            );
            a.line(
              [Offset(80, y), Offset(92, y + 1)],
              const Color(0x188fa5b3),
              width: .4,
            );
          }
        }
        break;
      case 'skirt':
        a.path(
          [
            27,
            2,
            39,
            5,
            61,
            5,
            73,
            2,
            79,
            25,
            84,
            50,
            99,
            94,
            70,
            100,
            31,
            100,
            1,
            94,
            17,
            50,
            21,
            25,
            27,
            2,
          ],
          color,
          stroke: edge,
        );
        seam([const Offset(27, 9), const Offset(73, 9)]);
        for (final x in [30.0, 42.0, 58.0, 70.0]) {
          seam([Offset(x, 14), Offset(50 + (x - 50) * 2, 95)]);
        }
        break;
      case 'shoes':
        for (final dx in [0.0, 53.0]) {
          canvas.save();
          canvas.translate(dx, 0);
          a.path(
            [
              20,
              9,
              31,
              5,
              37,
              21,
              35,
              47,
              40,
              64,
              43,
              79,
              34,
              88,
              16,
              96,
              2,
              94,
              1,
              84,
              12,
              66,
              13,
              44,
              14,
              20,
              20,
              9,
            ],
            color,
            stroke: edge,
          );
          a.path([
            21,
            14,
            27,
            10,
            31,
            18,
            30,
            42,
            27,
            54,
            20,
            56,
            18,
            44,
            19,
            26,
            21,
            14,
          ], const Color(0xffd7b79b));
          seam([const Offset(16, 62), const Offset(33, 58)], width: 2);
          seam([
            const Offset(3, 91),
            const Offset(17, 93),
            const Offset(40, 80),
          ], width: 1.5);
          canvas.restore();
        }
        break;
      case 'bag':
        canvas.drawArc(
          const Rect.fromLTWH(20, 0, 60, 95),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        a.rect(const Rect.fromLTWH(10, 40, 80, 57), color, radius: 10);
        a.rect(
          const Rect.fromLTWH(17, 45, 66, 38),
          Color.lerp(color, Colors.white, .12)!,
          radius: 8,
        );
        seam([const Offset(14, 67), const Offset(85, 67)]);
        a.rect(
          const Rect.fromLTWH(46, 63, 9, 9),
          const Color(0xffb79b60),
          radius: 2,
        );
        break;
      case 'hair':
        a.path([
          45,
          2,
          15,
          0,
          13,
          23,
          12,
          42,
          7,
          66,
          4,
          80,
          2,
          96,
          20,
          99,
          33,
          95,
          50,
          99,
          67,
          95,
          80,
          99,
          98,
          96,
          96,
          80,
          93,
          66,
          88,
          42,
          87,
          23,
          85,
          0,
          55,
          2,
          52,
          7,
          48,
          7,
          45,
          2,
        ], color);
        for (var x = 15.0; x < 90; x += 7) {
          seam([
            Offset(x, 30),
            Offset(x - 3, 68),
            Offset(x + 2, 96),
          ], width: .5);
        }
        break;
      case 'fringe':
        a.path([
          5,
          64,
          0,
          35,
          12,
          7,
          43,
          5,
          60,
          -4,
          85,
          3,
          94,
          25,
          99,
          48,
          100,
          82,
          96,
          99,
          86,
          91,
          89,
          63,
          80,
          29,
          64,
          23,
          51,
          41,
          29,
          34,
          17,
          65,
          15,
          87,
          10,
          100,
          4,
          91,
          8,
          77,
          5,
          64,
        ], color);
        break;
      case 'patch':
      case 'sparkle':
        final p = Path();
        final points = item.shape == 'patch' ? 5 : 4;
        for (var i = 0; i < points * 2; i++) {
          final angle = -math.pi / 2 + i * math.pi / points;
          final r = i.isEven ? 44.0 : 18.0;
          final pt = Offset(50 + math.cos(angle) * r, 50 + math.sin(angle) * r);
          if (i == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        p.close();
        canvas.drawPath(p, Paint()..color = color);
        canvas.drawPath(
          p,
          Paint()
            ..color = edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        break;
      case 'bottle':
        a.rect(
          const Rect.fromLTWH(32, 2, 36, 22),
          const Color(0xffd2b89b),
          radius: 4,
        );
        a.rect(const Rect.fromLTWH(22, 25, 56, 72), color, radius: 10);
        a.rect(
          const Rect.fromLTWH(28, 48, 44, 31),
          const Color(0xfff5eadc),
          radius: 2,
        );
        a.line([const Offset(37, 59), const Offset(63, 59)], edge);
        a.line([const Offset(42, 67), const Offset(58, 67)], edge);
        break;
      case 'tube':
        a.path(
          [
            22,
            3,
            40,
            5,
            60,
            5,
            78,
            3,
            73,
            39,
            69,
            63,
            65,
            83,
            55,
            86,
            45,
            86,
            35,
            83,
            31,
            63,
            27,
            39,
            22,
            3,
          ],
          color,
          stroke: edge,
        );
        a.rect(const Rect.fromLTWH(35, 83, 30, 15), edge, radius: 2);
        a.oval(const Rect.fromLTWH(40, 30, 20, 20), const Color(0xffe8b867));
        break;
      case 'comb':
        a.rect(const Rect.fromLTWH(10, 25, 80, 16), color, radius: 6);
        for (var x = 15.0; x < 87; x += 8) {
          a.rect(Rect.fromLTWH(x, 37, 4, 37), color, radius: 2);
        }
        break;
      case 'flower':
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(50, 50);
          canvas.rotate(math.pi / 4 * i);
          a.oval(const Rect.fromLTWH(-10, -42, 20, 34), color);
          canvas.restore();
        }
        a.oval(const Rect.fromLTWH(36, 36, 28, 28), const Color(0xffd4ad5d));
        break;
      case 'cup':
        canvas.drawOval(
          const Rect.fromLTWH(70, 31, 26, 36),
          Paint()
            ..color = edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        a.rect(const Rect.fromLTWH(12, 26, 66, 58), color, radius: 10);
        a.oval(const Rect.fromLTWH(12, 18, 66, 23), const Color(0xffe9d7bd));
        a.oval(const Rect.fromLTWH(18, 22, 54, 15), const Color(0xff9a6a46));
        a.oval(const Rect.fromLTWH(33, 25, 23, 9), const Color(0xffe3cbb0));
        break;
      case 'ribbon':
        a.path(
          [
            49,
            44,
            25,
            10,
            4,
            18,
            8,
            48,
            10,
            69,
            33,
            60,
            49,
            48,
            31,
            81,
            25,
            98,
            50,
            73,
            75,
            98,
            69,
            81,
            51,
            48,
            67,
            60,
            90,
            69,
            92,
            48,
            96,
            18,
            75,
            10,
            51,
            44,
            50,
            47,
            50,
            47,
            49,
            44,
          ],
          color,
          stroke: edge,
        );
        a.rect(const Rect.fromLTWH(43, 38, 14, 23), edge, radius: 5);
        break;
      default:
        a.rect(
          const Rect.fromLTWH(5, 5, 90, 90),
          const Color(0xffddc8bb),
          radius: 12,
        );
        seam([const Offset(25, 25), const Offset(75, 75)]);
        seam([const Offset(75, 25), const Offset(25, 75)]);
    }
    if (activated && (item.shape == 'patch' || item.shape == 'bottle')) {
      a.oval(const Rect.fromLTWH(80, 0, 18, 18), const Color(0xffd7b878));
      a.line(
        [const Offset(84, 9), const Offset(88, 13), const Offset(95, 5)],
        Colors.white,
        width: 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ItemPainter old) =>
      old.item.color != item.color ||
      old.item.shape != item.shape ||
      old.activated != activated;
}

class ScenePainter extends CustomPainter {
  final String scene;
  final double cropX, cropY;
  ScenePainter(this.scene, {this.cropX = 0, this.cropY = 0});
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 600);
    c.translate(cropX * 15, cropY * 15);
    final a = Art(c);
    final info = scenes.firstWhere(
      (s) => s.id == scene,
      orElse: () => scenes.first,
    );
    c.drawRect(
      const Rect.fromLTWH(-20, -20, 440, 640),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(Color(info.color), Colors.white, .28)!,
            Color(info.color),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 600)),
    );
    switch (scene) {
      case 'coast':
        a.rect(
          const Rect.fromLTWH(-20, 260, 440, 220),
          const Color(0xff8daeb8),
        );
        a.rect(
          const Rect.fromLTWH(-20, 450, 440, 180),
          const Color(0xffe5d7bf),
        );
        for (var y = 280.0; y < 470; y += 19) {
          a.line(
            [
              Offset(0, y),
              Offset(120, y + 4),
              Offset(290, y - 2),
              Offset(400, y + 1),
            ],
            const Color(0x50ffffff),
            width: 2,
          );
        }
        a.oval(const Rect.fromLTWH(290, 70, 55, 55), const Color(0xfff6e9c9));
        break;
      case 'garden':
        a.rect(const Rect.fromLTWH(90, 390, 230, 230), const Color(0xffd4c4ac));
        for (var i = 0; i < 15; i++) {
          final x = i < 8 ? i * 12.0 : 310 + (i - 8) * 15.0;
          final y = 70 + (i % 4) * 85.0;
          a.oval(
            Rect.fromLTWH(x - 45, y, 95, 170),
            Color.lerp(
              const Color(0xff667e61),
              const Color(0xff9cae87),
              (i % 4) / 4,
            )!,
          );
          a.line(
            [Offset(x, 200), Offset(x + 10, 470)],
            const Color(0xff748061),
            width: 3,
          );
        }
        for (var i = 0; i < 14; i++) {
          a.oval(
            Rect.fromLTWH(
              (i * 33 % 400).toDouble(),
              440 + (i % 3) * 17.0,
              8,
              8,
            ),
            const Color(0xfff0dfcb),
          );
        }
        break;
      case 'evening':
        a.rect(
          const Rect.fromLTWH(25, 45, 100, 275),
          const Color(0xff3a3b49),
          radius: 50,
        );
        a.rect(
          const Rect.fromLTWH(280, 45, 100, 275),
          const Color(0xff3a3b49),
          radius: 50,
        );
        for (var i = 0; i < 18; i++) {
          a.oval(
            Rect.fromLTWH(
              (i * 53 % 350 + 30).toDouble(),
              100 + (i * 37 % 185).toDouble(),
              3,
              3,
            ),
            const Color(0xffc5b38f),
          );
        }
        a.rect(
          const Rect.fromLTWH(-20, 430, 440, 200),
          const Color(0xff8e766e),
        );
        a.oval(const Rect.fromLTWH(-60, 365, 190, 40), const Color(0xffb59a81));
        a.rect(const Rect.fromLTWH(30, 396, 8, 160), const Color(0xff4e3d38));
        break;
      case 'gallery':
        a.rect(
          const Rect.fromLTWH(-20, 445, 440, 180),
          const Color(0xffc5b9a4),
        );
        a.rect(const Rect.fromLTWH(25, 110, 100, 150), const Color(0xff8c7468));
        a.rect(const Rect.fromLTWH(31, 116, 88, 138), const Color(0xffe5dbcb));
        a.oval(const Rect.fromLTWH(50, 135, 55, 95), const Color(0xffaf8371));
        a.rect(const Rect.fromLTWH(294, 150, 85, 118), const Color(0xffb1a38f));
        a.rect(const Rect.fromLTWH(300, 156, 73, 106), const Color(0xfff4ede2));
        a.line(
          [
            const Offset(310, 245),
            const Offset(340, 181),
            const Offset(365, 222),
          ],
          const Color(0xff879384),
          width: 7,
        );
        a.rect(const Rect.fromLTWH(318, 375, 60, 80), const Color(0xffece4d9));
        a.oval(const Rect.fromLTWH(330, 335, 35, 48), const Color(0xffb1a38f));
        break;
      default:
        a.rect(const Rect.fromLTWH(0, 435, 400, 165), const Color(0xffb69a7d));
        a.rect(
          const Rect.fromLTWH(15, 35, 106, 305),
          const Color(0xff7a6a50),
          radius: 48,
        );
        a.rect(
          const Rect.fromLTWH(22, 42, 92, 292),
          const Color(0xffdbe1d1),
          radius: 44,
        );
        a.line(
          [const Offset(68, 42), const Offset(68, 334)],
          const Color(0xff9f8c6f),
          width: 4,
        );
        a.line(
          [const Offset(22, 180), const Offset(113, 180)],
          const Color(0xff9f8c6f),
          width: 4,
        );
        a.path([
          110,
          70,
          170,
          185,
          230,
          305,
          300,
          445,
          250,
          470,
          150,
          450,
          80,
          435,
          92,
          310,
          103,
          180,
          110,
          70,
        ], const Color(0x28fff5da));
        a.oval(const Rect.fromLTWH(-55, 373, 185, 28), const Color(0xff785a42));
        a.rect(const Rect.fromLTWH(35, 396, 9, 146), const Color(0xff785a42));
        a.rect(
          const Rect.fromLTWH(310, 298, 105, 142),
          const Color(0xffa5886c),
        );
        a.rect(const Rect.fromLTWH(305, 290, 115, 10), const Color(0xff695443));
        a.rect(
          const Rect.fromLTWH(38, 347, 15, 28),
          const Color(0xffd3c5ae),
          radius: 4,
        );
        for (var i = 0; i < 5; i++) {
          final x = 31 + i * 6.0;
          final y = 321 + (i % 3) * 7.0;
          a.line([
            const Offset(45, 351),
            Offset(x + 4, y + 4),
          ], const Color(0xff788566));
          a.oval(Rect.fromLTWH(x, y, 10, 8), const Color(0xfff6f1df));
        }
        a.line(
          [const Offset(350, 0), const Offset(350, 95)],
          const Color(0xff65523f),
          width: 2,
        );
        a.oval(const Rect.fromLTWH(323, 88, 54, 20), const Color(0xff8f765b));
    }
    // Deterministic paper grain, packaged as code and available offline.
    final random = math.Random(42);
    for (var i = 0; i < 1600; i++) {
      a.oval(
        Rect.fromLTWH(
          random.nextDouble() * 400,
          random.nextDouble() * 600,
          .65,
          .65,
        ),
        const Color(0x0d302820),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene || old.cropX != cropX || old.cropY != cropY;
}
