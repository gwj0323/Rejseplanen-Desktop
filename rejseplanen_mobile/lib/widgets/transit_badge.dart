import 'package:flutter/material.dart';

class TransitBadgeInfo {
  final String display;
  final String fullName;
  final Color bg;
  final Color fg;
  final bool isSingle;
  final String category;

  TransitBadgeInfo({
    required this.display,
    required this.fullName,
    required this.bg,
    required this.fg,
    required this.isSingle,
    required this.category,
  });
}

class TransitBadgeHelper {
  static const Map<String, List<String>> _stogColors = {
    "A": ["#00A4EB", "#FFFFFF"],
    "B": ["#50AE30", "#FFFFFF"],
    "BX": ["#99C221", "#FFFFFF"],
    "C": ["#F68B1F", "#FFFFFF"],
    "E": ["#7670B3", "#FFFFFF"],
    "F": ["#F7A600", "#FFFFFF"],
    "H": ["#EC3400", "#FFFFFF"],
  };

  static const Map<String, List<String>> _metroColors = {
    "M1": ["#007D55", "#FFFFFF"],
    "M2": ["#FFC82D", "#111827"],
    "M3": ["#C72027", "#FFFFFF"],
    "M4": ["#0082C9", "#FFFFFF"],
  };

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse("0x$hex"));
  }

  static TransitBadgeInfo parse(String rawName, [String typeCode = ""]) {
    rawName = rawName.trim();
    typeCode = typeCode.trim().toUpperCase();

    // 1. Detect S-tog lines
    String cleanS = rawName
        .replaceAll(RegExp(r'^(S-tog|S-Tog|S-train|S)\s*', caseSensitive: false), '')
        .trim()
        .toUpperCase();
    bool isStog = typeCode.contains("S-TOG") ||
        typeCode == "S" ||
        (_stogColors.containsKey(cleanS) && cleanS.length <= 2);

    if (isStog && _stogColors.containsKey(cleanS)) {
      final pair = _stogColors[cleanS]!;
      return TransitBadgeInfo(
        display: cleanS,
        fullName: "S-tog Linje $cleanS",
        bg: _hexToColor(pair[0]),
        fg: _hexToColor(pair[1]),
        isSingle: cleanS.length == 1,
        category: "S-TOG",
      );
    }
    if (isStog) {
      return TransitBadgeInfo(
        display: cleanS.isNotEmpty ? cleanS : "S",
        fullName: "S-tog $cleanS".trim(),
        bg: _hexToColor("#DA291C"),
        fg: Colors.white,
        isSingle: cleanS.length <= 1,
        category: "S-TOG",
      );
    }

    // 2. Detect Metro lines
    final mMatch = RegExp(r'M([1-4])\b', caseSensitive: false).firstMatch(rawName);
    if (mMatch != null || typeCode.contains("MET") || typeCode.contains("METRO")) {
      String mCode = mMatch != null ? "M${mMatch.group(1)!.toUpperCase()}" : "MET";
      final pair = _metroColors[mCode] ?? ["#007D55", "#FFFFFF"];
      return TransitBadgeInfo(
        display: mCode,
        fullName: "Metro $mCode",
        bg: _hexToColor(pair[0]),
        fg: _hexToColor(pair[1]),
        isSingle: false,
        category: "METRO",
      );
    }

    // 3. Detect Movia Bus lines
    String cleanBus = rawName
        .replaceAll(RegExp(r'^(Bus|Bybus)\s*', caseSensitive: false), '')
        .trim()
        .toUpperCase();
    if (typeCode.contains("BUS") || RegExp(r'^\d+[A-Z]?$').hasMatch(cleanBus)) {
      String bgHex = "#F59E0B";
      String fgHex = "#111827";
      if (cleanBus.endsWith("C")) {
        bgHex = "#00A5CC"; fgHex = "#FFFFFF";
      } else if (cleanBus.endsWith("A")) {
        bgHex = "#B8211C"; fgHex = "#FFFFFF";
      } else if (cleanBus.endsWith("S")) {
        bgHex = "#0065AA"; fgHex = "#FFFFFF";
      } else if (cleanBus.endsWith("E")) {
        bgHex = "#00B26B"; fgHex = "#FFFFFF";
      } else if (cleanBus.endsWith("N")) {
        bgHex = "#1E293B"; fgHex = "#FFFFFF";
      } else if (cleanBus.endsWith("R")) {
        bgHex = "#005776"; fgHex = "#FFFFFF";
      }

      return TransitBadgeInfo(
        display: cleanBus.isNotEmpty ? cleanBus : rawName,
        fullName: "Bus $cleanBus",
        bg: _hexToColor(bgHex),
        fg: _hexToColor(fgHex),
        isSingle: false,
        category: "BUS",
      );
    }

    // 4. Trains & Other
    final uName = rawName.toUpperCase();
    if (uName.startsWith("ICL") || typeCode.contains("ICL")) {
      String num = rawName.replaceAll(RegExp(r'^(InterCityLyn|ICL)\s*', caseSensitive: false), '').trim();
      String disp = num.isNotEmpty ? "ICL $num" : "ICL";
      return TransitBadgeInfo(display: disp, fullName: "InterCityLyn $disp", bg: _hexToColor("#8E001A"), fg: Colors.white, isSingle: false, category: "ICL");
    }
    if (uName.startsWith("IC") || typeCode.contains("IC")) {
      String num = rawName.replaceAll(RegExp(r'^(InterCity|IC)\s*', caseSensitive: false), '').trim();
      String disp = num.isNotEmpty ? "IC $num" : "IC";
      return TransitBadgeInfo(display: disp, fullName: "InterCity $disp", bg: _hexToColor("#C72027"), fg: Colors.white, isSingle: false, category: "IC");
    }
    if (uName.startsWith("REGIONAL") || uName.startsWith("RE") || typeCode.contains("RE")) {
      String num = rawName.replaceAll(RegExp(r'^(Regionaltog|Regional|RE)\s*', caseSensitive: false), '').trim();
      String disp = num.isNotEmpty ? "Re $num" : "Re";
      return TransitBadgeInfo(display: disp, fullName: "Regionaltog $disp", bg: _hexToColor("#005776"), fg: Colors.white, isSingle: false, category: "RE");
    }
    if (uName.contains("ØRESUND") || uName.startsWith("ØT") || uName.startsWith("OT")) {
      String num = rawName.replaceAll(RegExp(r'^(Øresundstog|Oresundstag|ØT|OT)\s*', caseSensitive: false), '').trim();
      String disp = num.isNotEmpty ? "ØT $num" : "ØT";
      return TransitBadgeInfo(display: disp, fullName: "Øresundstog $disp", bg: _hexToColor("#005776"), fg: Colors.white, isSingle: false, category: "RE");
    }
    if (uName.contains("LETBANE") || typeCode.contains("LETBANE")) {
      return TransitBadgeInfo(display: rawName, fullName: "Letbane $rawName", bg: _hexToColor("#7B1FA2"), fg: Colors.white, isSingle: false, category: "LETBANE");
    }
    if (uName.contains("L-TOG") || uName.contains("LOKALTOG")) {
      return TransitBadgeInfo(display: rawName, fullName: "Lokaltog $rawName", bg: _hexToColor("#0284C7"), fg: Colors.white, isSingle: false, category: "LOKALTOG");
    }
    if (typeCode.contains("FER") || uName.contains("FÆRGE") || uName.contains("FERRY")) {
      return TransitBadgeInfo(display: rawName, fullName: "Færge $rawName", bg: _hexToColor("#0284C7"), fg: Colors.white, isSingle: false, category: "FERRY");
    }
    if (typeCode.contains("WALK") || uName.contains("GÅ") || uName.contains("WALK")) {
      return TransitBadgeInfo(display: "Walk", fullName: "Walk", bg: _hexToColor("#64748B"), fg: Colors.white, isSingle: false, category: "WALK");
    }

    // Default fallback
    return TransitBadgeInfo(
      display: rawName.isNotEmpty ? rawName : typeCode,
      fullName: rawName,
      bg: typeCode.contains("TOG") ? _hexToColor("#C72027") : _hexToColor("#4B5563"),
      fg: Colors.white,
      isSingle: rawName.length == 1,
      category: typeCode.isNotEmpty ? typeCode : "OTHER",
    );
  }
}

class TransitBadge extends StatelessWidget {
  final String text;
  final String typeCode;
  final double? fontSize;
  final double? height;

  const TransitBadge({
    super.key,
    required this.text,
    this.typeCode = "TOG",
    this.fontSize,
    this.height = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final info = TransitBadgeHelper.parse(text, typeCode);
    final h = height ?? 24.0;
    final w = info.isSingle ? h * 1.05 : null;

    final double calcFontSize = fontSize ??
        (info.isSingle
            ? 13.0
            : (info.display.length > 7
                ? 10.0
                : (info.display.length > 4 ? 11.0 : 12.0)));

    return Container(
      height: h,
      width: w,
      padding: info.isSingle
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: info.bg,
        borderRadius: BorderRadius.circular(info.isSingle ? 5.0 : 6.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        info.display,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: info.fg,
          fontWeight: FontWeight.bold,
          fontSize: calcFontSize,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
