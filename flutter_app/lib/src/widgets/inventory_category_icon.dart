import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum InventoryCategoryIconType {
  detergent,
  soap,
  liquid,
  disinfectant,
  bleach,
  softener,
}

class InventoryCategoryIcon extends StatelessWidget {
  const InventoryCategoryIcon({
    super.key,
    required this.type,
    this.size = 52,
  });

  final InventoryCategoryIconType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      switch (type) {
        InventoryCategoryIconType.detergent => _detergentSvg,
        InventoryCategoryIconType.soap => _soapSvg,
        InventoryCategoryIconType.liquid => _liquidSvg,
        InventoryCategoryIconType.disinfectant => _disinfectantSvg,
        InventoryCategoryIconType.bleach => _bleachSvg,
        InventoryCategoryIconType.softener => _softenerSvg,
      },
      width: size,
      height: size,
    );
  }
}

const _detergentSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="a" x1="18" y1="16" x2="108" y2="112" gradientUnits="userSpaceOnUse">
      <stop stop-color="#DDF5FF"/>
      <stop offset="1" stop-color="#BCE3FF"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#a)"/>
  <path d="M46 32h36v12H46z" fill="#2E6F95"/>
  <path d="M40 44h48l6 16v32a10 10 0 0 1-10 10H44A10 10 0 0 1 34 92V60z" fill="#F8FDFF" stroke="#6A879C" stroke-width="3"/>
  <rect x="46" y="58" width="36" height="24" rx="8" fill="#78C4F8"/>
  <path d="M56 70c4-9 12-10 16 0-4 7-12 7-16 0Z" fill="#FFFFFF"/>
</svg>
''';

const _soapSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="b" x1="16" y1="18" x2="110" y2="110" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF1DD"/>
      <stop offset="1" stop-color="#FFD9B0"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#b)"/>
  <rect x="28" y="58" width="72" height="28" rx="14" fill="#F6C98B" stroke="#BE8B49" stroke-width="3"/>
  <circle cx="46" cy="42" r="8" fill="#FFFFFF" fill-opacity=".9"/>
  <circle cx="63" cy="36" r="11" fill="#FFFFFF" fill-opacity=".9"/>
  <circle cx="82" cy="44" r="7" fill="#FFFFFF" fill-opacity=".9"/>
</svg>
''';

const _liquidSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="c" x1="18" y1="12" x2="108" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#EAFBF4"/>
      <stop offset="1" stop-color="#C7F0DE"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#c)"/>
  <path d="M52 30h24v14H52z" fill="#417A62"/>
  <path d="M44 44h40l8 18v28a12 12 0 0 1-12 12H48a12 12 0 0 1-12-12V62z" fill="#FFFFFF" stroke="#6A8F81" stroke-width="3"/>
  <path d="M49 76c8-14 22-14 30 0-8 10-22 10-30 0Z" fill="#57C78E"/>
</svg>
''';

const _disinfectantSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="d" x1="16" y1="14" x2="110" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#F0EEFF"/>
      <stop offset="1" stop-color="#D7D0FF"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#d)"/>
  <rect x="48" y="26" width="32" height="16" rx="6" fill="#7C6FD6"/>
  <path d="M40 42h48l4 12v36a12 12 0 0 1-12 12H48a12 12 0 0 1-12-12V54z" fill="#FFFFFF" stroke="#7E7AA5" stroke-width="3"/>
  <path d="M64 56v26M51 69h26" stroke="#53B479" stroke-width="7" stroke-linecap="round"/>
</svg>
''';

const _bleachSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="e" x1="18" y1="14" x2="112" y2="112" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF0F0"/>
      <stop offset="1" stop-color="#FFD2D2"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#e)"/>
  <path d="M50 28h28v14H50z" fill="#BE6262"/>
  <path d="M44 42h40l6 16v32a12 12 0 0 1-12 12H50a12 12 0 0 1-12-12V58z" fill="#FFFFFF" stroke="#B78484" stroke-width="3"/>
  <path d="M60 58h8v18h-8zM60 82h8v8h-8z" fill="#E05C5C"/>
</svg>
''';

const _softenerSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="f" x1="18" y1="16" x2="110" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFE9F5"/>
      <stop offset="1" stop-color="#FFCDE6"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#f)"/>
  <rect x="48" y="26" width="32" height="14" rx="6" fill="#B4608C"/>
  <path d="M42 40h44l6 18v30a12 12 0 0 1-12 12H48a12 12 0 0 1-12-12V58z" fill="#FFFFFF" stroke="#B88AA4" stroke-width="3"/>
  <path d="M64 80c-14-9-16-19-9-24 4-3 9-1 11 2 2-3 7-5 11-2 7 5 5 15-13 24Z" fill="#F08EBB"/>
</svg>
''';
