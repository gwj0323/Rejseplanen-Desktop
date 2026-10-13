import re
from PyQt6.QtWidgets import QFrame, QLabel, QHBoxLayout
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont
from config import config

# Official S-train (S-tog) line colors according to DSB & Banedanmark
STOG_COLORS = {
    "A": ("#00A4EB", "#FFFFFF"),   # Line A: Cyan / Light Blue
    "B": ("#50AE30", "#FFFFFF"),   # Line B: Forest Green
    "BX": ("#99C221", "#FFFFFF"),  # Line Bx: Light Green / Olive
    "C": ("#F68B1F", "#FFFFFF"),   # Line C: Orange
    "E": ("#7670B3", "#FFFFFF"),   # Line E: Purple / Violet
    "F": ("#F7A600", "#FFFFFF"),   # Line F: Gold / Yellow-Orange
    "H": ("#EC3400", "#FFFFFF"),   # Line H: Red
}

# Copenhagen Metro line colors
METRO_COLORS = {
    "M1": ("#007D55", "#FFFFFF"),  # M1: Dark Green
    "M2": ("#FFC82D", "#111827"),  # M2: Yellow (Dark text for readability)
    "M3": ("#C72027", "#FFFFFF"),  # M3: Cityringen Red
    "M4": ("#0082C9", "#FFFFFF"),  # M4: Nordhavn Blue
}

def parse_transit_badge(raw_name: str, type_code: str = "") -> dict:
    """
    Parse transit line name and type code into clean display text, official colors,
    and tooltip description matching Mit Tog and DSB / Rejseplanen standards.
    """
    raw_name = str(raw_name or "").strip()
    type_code = str(type_code or "").strip().upper()
    
    # 1. Detect S-tog lines
    clean_s = re.sub(r"^(S-tog|S-Tog|S-train|S)\s*", "", raw_name, flags=re.IGNORECASE).strip().upper()
    is_stog = ("S-TOG" in type_code or type_code == "S" or (clean_s in STOG_COLORS and len(clean_s) <= 2))
    if is_stog and clean_s in STOG_COLORS:
        bg, fg = STOG_COLORS[clean_s]
        return {
            "display": clean_s,
            "full_name": f"S-tog Linje {clean_s}",
            "bg": bg,
            "fg": fg,
            "is_single": len(clean_s) == 1,
            "category": "S-TOG"
        }
    if is_stog:
        return {
            "display": clean_s or "S",
            "full_name": f"S-tog {clean_s}".strip(),
            "bg": "#DA291C",
            "fg": "#FFFFFF",
            "is_single": len(clean_s) <= 1,
            "category": "S-TOG"
        }

    # 2. Detect Metro lines
    m_match = re.search(r"M([1-4])\b", raw_name, flags=re.IGNORECASE)
    if m_match or "MET" in type_code or "METRO" in type_code:
        m_code = f"M{m_match.group(1).upper()}" if m_match else "MET"
        bg, fg = METRO_COLORS.get(m_code, ("#007D55", "#FFFFFF"))
        return {
            "display": m_code,
            "full_name": f"Metro {m_code}",
            "bg": bg,
            "fg": fg,
            "is_single": False,
            "category": "METRO"
        }

    # 3. Detect Movia Bus lines
    clean_bus = re.sub(r"^(Bus|Bybus)\s*", "", raw_name, flags=re.IGNORECASE).strip().upper()
    if "BUS" in type_code or re.match(r"^\d+[A-Z]?$", clean_bus):
        if clean_bus.endswith("C"):
            bg, fg = "#00A5CC", "#FFFFFF"  # C-bus (e.g. 5C)
        elif clean_bus.endswith("A"):
            bg, fg = "#B8211C", "#FFFFFF"  # A-bus (e.g. 1A, 2A, 6A)
        elif clean_bus.endswith("S"):
            bg, fg = "#0065AA", "#FFFFFF"  # S-bus (e.g. 150S, 350S)
        elif clean_bus.endswith("E"):
            bg, fg = "#00B26B", "#FFFFFF"  # E-bus (e.g. 15E)
        elif clean_bus.endswith("N"):
            bg, fg = "#1E293B", "#FFFFFF"  # Night bus
        elif clean_bus.endswith("R"):
            bg, fg = "#005776", "#FFFFFF"  # Regional bus
        else:
            bg, fg = "#F59E0B", "#111827"  # Regular city/regional bus
            
        return {
            "display": clean_bus,
            "full_name": f"Bus {clean_bus}",
            "bg": bg,
            "fg": fg,
            "is_single": False,
            "category": "BUS"
        }

    # 4. Detect Trains (InterCity, Regional, Lokaltog, Light Rail)
    u_name = raw_name.upper()
    if u_name.startswith("ICL") or "ICL" in type_code:
        return {"display": raw_name, "full_name": f"InterCityLyn {raw_name}", "bg": "#8E001A", "fg": "#FFFFFF", "is_single": False, "category": "ICL"}
    if u_name.startswith("IC") or "IC" in type_code:
        return {"display": raw_name, "full_name": f"InterCity {raw_name}", "bg": "#C72027", "fg": "#FFFFFF", "is_single": False, "category": "IC"}
    if u_name.startswith("RE") or "RE" in type_code:
        return {"display": raw_name, "full_name": f"Regionaltog {raw_name}", "bg": "#005776", "fg": "#FFFFFF", "is_single": False, "category": "RE"}
    if "LETBANE" in u_name or "LETBANE" in type_code:
        return {"display": raw_name, "full_name": f"Letbane {raw_name}", "bg": "#7B1FA2", "fg": "#FFFFFF", "is_single": False, "category": "LETBANE"}
    if "L-TOG" in u_name or "LOKALTOG" in u_name:
        return {"display": raw_name, "full_name": f"Lokaltog {raw_name}", "bg": "#0284C7", "fg": "#FFFFFF", "is_single": False, "category": "LOKALTOG"}
    if "FER" in type_code or "FÆRGE" in u_name or "FERRY" in u_name:
        return {"display": raw_name, "full_name": f"Færge {raw_name}", "bg": "#0284C7", "fg": "#FFFFFF", "is_single": False, "category": "FERRY"}
    if "WALK" in type_code or "GÅ" in u_name or "WALK" in u_name:
        walk_txt = "Gå" if config.language == "da_DK" else ("步行" if config.language == "zh_CN" else "Walk")
        return {"display": walk_txt, "full_name": walk_txt, "bg": "#64748B", "fg": "#FFFFFF", "is_single": False, "category": "WALK"}

    # Default Train / Transit fallback
    return {
        "display": raw_name,
        "full_name": raw_name,
        "bg": "#C72027" if "TOG" in type_code else "#4B5563",
        "fg": "#FFFFFF",
        "is_single": len(raw_name) == 1,
        "category": type_code or "OTHER"
    }

class TransitBadge(QFrame):
    """
    Mit Tog style minimalist, flat rounded transit badge.
    - S-train lines (A, B, C, E, etc.) render as crisp, square color-coded icons.
    - Metro, buses, and trains render with authentic Danish color coding.
    """
    def __init__(self, text: str, type_code: str = "TOG", parent=None):
        super().__init__(parent)
        self.setObjectName("TransitBadge")
        
        info = parse_transit_badge(text, type_code)
        self.setToolTip(info["full_name"])
        
        bg = info["bg"]
        fg = info["fg"]
        display_text = info["display"]
        is_single = info["is_single"]
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        self.label = QLabel(display_text, self)
        f = QFont("Segoe UI", 11 if is_single else 10)
        f.setBold(True)
        self.label.setFont(f)
        self.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.label)
        
        # Geometry: single-letter S-tog lines are clean 26x24 squares; others are sleek pills
        if is_single:
            self.setFixedSize(26, 24)
            padding_style = "padding: 0px;"
        else:
            self.setFixedHeight(24)
            self.setMinimumWidth(30)
            padding_style = "padding: 0px 6px;"
            
        self.setStyleSheet(f"""
            QFrame#TransitBadge {{
                background-color: {bg};
                border-radius: 4px;
                {padding_style}
            }}
            QLabel {{
                color: {fg};
                background: transparent;
            }}
        """)

class StatusBadge(QFrame):
    """
    WinUI 3 & Mit Tog style clean real-time status pill (On Time, Delayed, Cancelled).
    """
    def __init__(self, text: str, status: str = "normal", parent=None):
        super().__init__(parent)
        self.setObjectName("StatusBadge")
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 1, 6, 1)
        layout.setSpacing(0)
        
        self.label = QLabel(text, self)
        f = QFont("Segoe UI", 9)
        f.setBold(True)
        self.label.setFont(f)
        self.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.label)
        
        self.setFixedHeight(22)
        self.update_status(text, status)

    def update_status(self, text: str, status: str = "normal"):
        self.label.setText(text)
        if status == "normal":
            bg = "rgba(16, 185, 129, 0.15)"
            fg = "#059669"
            border = "1px solid rgba(16, 185, 129, 0.3)"
        elif status == "minor_delay":
            bg = "rgba(245, 158, 11, 0.15)"
            fg = "#D97706"
            border = "1px solid rgba(245, 158, 11, 0.3)"
        elif status == "delayed":
            bg = "rgba(239, 68, 68, 0.15)"
            fg = "#DC2626"
            border = "1px solid rgba(239, 68, 68, 0.3)"
        elif status == "cancelled":
            bg = "#B91C1C"
            fg = "#FFFFFF"
            border = "none"
        else:
            bg = "rgba(100, 116, 139, 0.12)"
            fg = "#475569"
            border = "none"
            
        self.setStyleSheet(f"""
            QFrame#StatusBadge {{
                background-color: {bg};
                border-radius: 4px;
                border: {border};
            }}
            QLabel {{
                color: {fg};
                background: transparent;
            }}
        """)
