import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvgIcons {
  static Widget sparkles({double size = 14, Color color = const Color(0xFF2CB8A0)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l1.912 5.813a2 2 0 001.275 1.275L21 12l-5.813 1.912a2 2 0 00-1.275 1.275L12 21l-1.912-5.813a2 2 0 00-1.275-1.275L3 12l5.813-1.912a2 2 0 001.275-1.275L12 3z"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget lock({double size = 14, Color color = const Color(0xFFE89A58)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget cash({double size = 14, Color color = const Color(0xFF2CB8A0)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M6 12h.01M18 12h.01"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget bank({double size = 14, Color color = const Color(0xFF6C8CFF)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18M3 10h18M5 10v11M9 10v11M15 10v11M19 10v11M12 2L2 7h20L12 2z"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget trendingUp({double size = 14, Color color = const Color(0xFFCD5C52)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget trendingDown({double size = 14, Color color = const Color(0xFF147D64)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 18 13.5 8.5 8.5 13.5 1 6"/><polyline points="17 18 23 18 23 12"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget alertTriangle({double size = 14, Color color = const Color(0xFFE89A58)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget celebration({double size = 14, Color color = const Color(0xFF2CB8A0)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5.8 11.3L2 22l10.7-3.8M4 3l.9 3M17 3l-.9 3M11 2l.3 3.8M14.5 9.5l2 2M7.5 9.5l-2 2"/><circle cx="12" cy="13" r="3"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget lightbulb({double size = 14, Color color = const Color(0xFFE89A58)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18h6M10 22h4M15 8.24c.75-.75 1.25-1.75 1.25-2.74A5.5 5.5 0 0011 0a5.5 5.5 0 00-5.25 5.5c0 .99.5 1.99 1.25 2.74L8.5 12h7l-0.5-3.76z"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }

  static Widget trash({double size = 14, Color color = const Color(0xFFCD5C52)}) {
    const svg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>''';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}
