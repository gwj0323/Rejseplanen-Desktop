from typing import Callable, List
from config import config

TRANSLATIONS = {
    "zh_CN": {
        "app_title": "RejseNu",
        "nav_trip": "行程规划",
        "nav_board": "实时大屏",
        "nav_station": "站点查询",
        "nav_favorites": "收藏",
        "nav_settings": "设置",
        
        # Trip planner
        "trip_title": "行程规划",
        "trip_subtitle": "",
        "trip_origin": "起点",
        "trip_dest": "终点",
        "trip_origin_placeholder": "起点站，如 København H",
        "trip_dest_placeholder": "终点站，如 Nørreport St.",
        "trip_swap": "对调起点终点",
        "trip_date": "日期",
        "trip_time": "时间",
        "trip_now": "当前时间",
        "trip_mode_dep": "出发时间",
        "trip_mode_arr": "到达时间",
        "trip_search": "查询方案",
        "trip_searching": "正在查询...",
        "trip_quick_select": "快捷选择",
        "trip_filter": "交通方式",
        "filter_train": "火车",
        "filter_stog": "S-tog",
        "filter_metro": "地铁",
        "filter_bus": "公交",
        "filter_ferry": "轮渡",
        "trip_results": "方案列表",
        "trip_duration": "耗时",
        "trip_changes": "次换乘",
        "trip_direct": "直达",
        "trip_save_fav": "收藏路线",
        "trip_step_by_step": "换乘详情",
        "trip_platform": "站台",
        "trip_walk": "步行",
        "trip_delay": "晚点",
        "trip_on_time": "准点",
        "trip_no_results": "未找到乘车方案",
        "trip_select_both_error": "请填写起点和终点站",
        
        # Board
        "board_title": "实时大屏",
        "board_subtitle": "",
        "board_station": "车站",
        "board_station_placeholder": "输入站名或选择快捷站...",
        "board_type_dep": "发车",
        "board_type_arr": "到达",
        "board_refresh": "刷新",
        "board_auto_refresh": "自动刷新 (30s)",
        "board_col_line": "线路",
        "board_col_dir": "终点 / 方向",
        "board_col_time": "计划时间",
        "board_col_realtime": "实时",
        "board_col_track": "站台",
        "board_col_status": "状态",
        "status_ontime": "准点",
        "status_delayed": "晚点",
        "status_cancelled": "停运",
        "board_add_fav": "收藏车站",
        "board_no_departures": "当前暂无车次记录",
        
        # Station Explorer
        "station_title": "站点查询",
        "station_subtitle": "",
        "station_search_placeholder": "搜索车站或地址...",
        "station_search_btn": "搜索",
        "station_nearby_title": "周边站点 (GPS)",
        "station_lat": "纬度",
        "station_lon": "经度",
        "station_find_nearby": "探测周边",
        "station_preset_cph": "哥本哈根市中心",
        "station_preset_aarhus": "奥胡斯市中心",
        "station_action_dep": "实时大屏",
        "station_action_plan": "设为起点",
        "station_id": "编号",
        "station_coords": "坐标",
        
        # Favorites
        "fav_title": "收藏与历史",
        "fav_subtitle": "",
        "fav_stations_title": "常用车站",
        "fav_trips_title": "常用路线",
        "fav_history_title": "历史记录",
        "fav_empty": "暂无收藏",
        "fav_history_empty": "暂无历史记录",
        "fav_remove": "删除",
        "fav_go": "查询",
        "fav_clear_history": "清空",
        
        # Settings
        "settings_title": "设置",
        "settings_subtitle": "",
        "settings_api_group": "API 配置",
        "settings_api_key_label": "API 密钥 (accessId)",
        "settings_api_key_placeholder": "输入 accessId 密钥...",
        "settings_api_key_desc": "Rejseplanen accessId，可在 labs.rejseplanen.dk 申请（非商业免费）",
        "settings_base_url_label": "接口地址",
        "settings_base_url_desc": "默认: https://www.rejseplanen.dk/api",
        "settings_test_conn_btn": "测试连接",
        "settings_mock_fallback_label": "离线演示数据",
        "settings_mock_fallback_desc": "无网络或未配置 Key 时使用离线模拟数据",
        "settings_labs_link_btn": "申请 API Key (labs.rejseplanen.dk) ↗",
        "settings_appearance_group": "外观与语言",
        "settings_lang_label": "语言",
        "settings_theme_label": "主题",
        "theme_auto": "跟随系统",
        "theme_light": "浅色",
        "theme_dark": "深色",
        "settings_about_group": "关于",
        "settings_about_desc": "RejseNu - 丹麦公共出行客户端",
        "settings_about_author": "作者: gwj0323",
        "settings_save_btn": "保存设置",
        "settings_saved_msg": "设置已保存",
        
        # Common
        "loading": "加载中...",
        "error": "错误",
        "success": "成功",
        "info": "提示",
        "mock_badge": "演示模式",
        "live_badge": "实时数据",
        "conn_ok": "API 连接成功 (HTTP 200 OK)",
        "conn_fail": "API 连接失败: ",
        "conn_no_key": "请先输入 accessId",
        "saved_to_fav": "已收藏",
        "already_in_fav": "已在收藏中",
        "diag_key_label": "API Key",
        "diag_key_configured": "已配置 ({masked})",
        "diag_key_missing": "未配置",
        "diag_mode_label": "运行模式",
        "diag_mode_mock": "演示模式",
        "diag_mode_live_fallback": "官方 API (失败回退演示)",
        "diag_mode_live_strict": "官方 API",
        "diag_conn_label": "接口状态",
        "diag_conn_ok_short": "正常 (200 OK)",
        "diag_conn_none": "未测试"
    },
    
    "en_US": {
        "app_title": "RejseNu",
        "nav_trip": "Planner",
        "nav_board": "Live Board",
        "nav_station": "Stations",
        "nav_favorites": "Favorites",
        "nav_settings": "Settings",
        
        # Trip planner
        "trip_title": "Journey Planner",
        "trip_subtitle": "",
        "trip_origin": "Origin",
        "trip_dest": "Destination",
        "trip_origin_placeholder": "Origin, e.g. København H",
        "trip_dest_placeholder": "Destination, e.g. Nørreport St.",
        "trip_swap": "Swap",
        "trip_date": "Date",
        "trip_time": "Time",
        "trip_now": "Now",
        "trip_mode_dep": "Depart",
        "trip_mode_arr": "Arrive",
        "trip_search": "Find Journeys",
        "trip_searching": "Searching...",
        "trip_quick_select": "Quick select",
        "trip_filter": "Modes",
        "filter_train": "Train",
        "filter_stog": "S-tog",
        "filter_metro": "Metro",
        "filter_bus": "Bus",
        "filter_ferry": "Ferry",
        "trip_results": "Suggested Routes",
        "trip_duration": "Duration",
        "trip_changes": "transfers",
        "trip_direct": "Direct",
        "trip_save_fav": "Save route",
        "trip_step_by_step": "Details",
        "trip_platform": "Track",
        "trip_walk": "Walk",
        "trip_delay": "Delay",
        "trip_on_time": "On time",
        "trip_no_results": "No journeys found.",
        "trip_select_both_error": "Please enter origin and destination stations.",
        
        # Board
        "board_title": "Live Departures",
        "board_subtitle": "",
        "board_station": "Station",
        "board_station_placeholder": "Station name...",
        "board_type_dep": "Departures",
        "board_type_arr": "Arrivals",
        "board_refresh": "Refresh",
        "board_auto_refresh": "Auto refresh (30s)",
        "board_col_line": "Line",
        "board_col_dir": "Destination",
        "board_col_time": "Time",
        "board_col_realtime": "Real-time",
        "board_col_track": "Track",
        "board_col_status": "Status",
        "status_ontime": "On time",
        "status_delayed": "Delayed",
        "status_cancelled": "Cancelled",
        "board_add_fav": "Save station",
        "board_no_departures": "No departures found.",
        
        # Station Explorer
        "station_title": "Stations",
        "station_subtitle": "",
        "station_search_placeholder": "Search station or address...",
        "station_search_btn": "Search",
        "station_nearby_title": "Nearby (GPS)",
        "station_lat": "Latitude",
        "station_lon": "Longitude",
        "station_find_nearby": "Find Nearby",
        "station_preset_cph": "Copenhagen Center",
        "station_preset_aarhus": "Aarhus Center",
        "station_action_dep": "View Board",
        "station_action_plan": "Depart Here",
        "station_id": "ID",
        "station_coords": "Coordinates",
        
        # Favorites
        "fav_title": "Favorites & History",
        "fav_subtitle": "",
        "fav_stations_title": "Stations",
        "fav_trips_title": "Routes",
        "fav_history_title": "Recent Searches",
        "fav_empty": "No favorites yet",
        "fav_history_empty": "No history yet",
        "fav_remove": "Remove",
        "fav_go": "Go",
        "fav_clear_history": "Clear",
        
        # Settings
        "settings_title": "Settings",
        "settings_subtitle": "",
        "settings_api_group": "API Configuration",
        "settings_api_key_label": "API Key (accessId)",
        "settings_api_key_placeholder": "Enter accessId...",
        "settings_api_key_desc": "Rejseplanen API accessId (from labs.rejseplanen.dk)",
        "settings_base_url_label": "Base URL",
        "settings_base_url_desc": "Default: https://www.rejseplanen.dk/api",
        "settings_test_conn_btn": "Test Connection",
        "settings_mock_fallback_label": "Offline Demo Data",
        "settings_mock_fallback_desc": "Use demo data when offline or without key",
        "settings_labs_link_btn": "Get API Key (labs.rejseplanen.dk) ↗",
        "settings_appearance_group": "Appearance",
        "settings_lang_label": "Language",
        "settings_theme_label": "Theme",
        "theme_auto": "Follow System",
        "theme_light": "Light",
        "theme_dark": "Dark",
        "settings_about_group": "About",
        "settings_about_desc": "RejseNu - Denmark Transit Companion",
        "settings_about_author": "Author: gwj0323",
        "settings_save_btn": "Save Settings",
        "settings_saved_msg": "Settings saved",
        
        # Common
        "loading": "Loading...",
        "error": "Error",
        "success": "Success",
        "info": "Notice",
        "mock_badge": "Demo",
        "live_badge": "Live",
        "conn_ok": "Connection successful (HTTP 200 OK)",
        "conn_fail": "Connection failed: ",
        "conn_no_key": "Please enter an accessId first.",
        "saved_to_fav": "Saved to favorites.",
        "already_in_fav": "Already in favorites.",
        "diag_key_label": "API Key",
        "diag_key_configured": "Configured ({masked})",
        "diag_key_missing": "Not configured",
        "diag_mode_label": "Mode",
        "diag_mode_mock": "Demo",
        "diag_mode_live_fallback": "Live API (with demo fallback)",
        "diag_mode_live_strict": "Live API",
        "diag_conn_label": "Status",
        "diag_conn_ok_short": "Normal (200 OK)",
        "diag_conn_none": "Not tested"
    },
    
    "da_DK": {
        "app_title": "RejseNu",
        "nav_trip": "Rejseplan",
        "nav_board": "Afgange",
        "nav_station": "Stationer",
        "nav_favorites": "Favoritter",
        "nav_settings": "Indstillinger",
        
        # Trip planner
        "trip_title": "Rejseplan",
        "trip_subtitle": "",
        "trip_origin": "Fra",
        "trip_dest": "Til",
        "trip_origin_placeholder": "Fra, f.eks. København H",
        "trip_dest_placeholder": "Til, f.eks. Nørreport St.",
        "trip_swap": "Byt",
        "trip_date": "Dato",
        "trip_time": "Tid",
        "trip_now": "Nu",
        "trip_mode_dep": "Afgang",
        "trip_mode_arr": "Ankomst",
        "trip_search": "Find rejser",
        "trip_searching": "Søger...",
        "trip_quick_select": "Hurtigvalg",
        "trip_filter": "Transportmidler",
        "filter_train": "Tog",
        "filter_stog": "S-tog",
        "filter_metro": "Metro",
        "filter_bus": "Bus",
        "filter_ferry": "Færge",
        "trip_results": "Rejseforslag",
        "trip_duration": "Rejsetid",
        "trip_changes": "skift",
        "trip_direct": "Direkte",
        "trip_save_fav": "Gem rejse",
        "trip_step_by_step": "Detaljer",
        "trip_platform": "Spor",
        "trip_walk": "Gå",
        "trip_delay": "Forsinkelse",
        "trip_on_time": "Til tiden",
        "trip_no_results": "Ingen rejser fundet.",
        "trip_select_both_error": "Angiv venligst både fra og til station.",
        
        # Board
        "board_title": "Afgangstavle",
        "board_subtitle": "",
        "board_station": "Station",
        "board_station_placeholder": "Stationsnavn...",
        "board_type_dep": "Afgange",
        "board_type_arr": "Ankomster",
        "board_refresh": "Opdater",
        "board_auto_refresh": "Auto-opdatering (30s)",
        "board_col_line": "Linje",
        "board_col_dir": "Retning",
        "board_col_time": "Tid",
        "board_col_realtime": "Realtid",
        "board_col_track": "Spor",
        "board_col_status": "Status",
        "status_ontime": "Til tiden",
        "status_delayed": "Forsinket",
        "status_cancelled": "Aflyst",
        "board_add_fav": "Gem station",
        "board_no_departures": "Ingen afgange fundet.",
        
        # Station Explorer
        "station_title": "Stationer",
        "station_subtitle": "",
        "station_search_placeholder": "Søg station eller adresse...",
        "station_search_btn": "Søg",
        "station_nearby_title": "I nærheden (GPS)",
        "station_lat": "Breddegrad",
        "station_lon": "Længdegrad",
        "station_find_nearby": "Find i nærheden",
        "station_preset_cph": "København Centrum",
        "station_preset_aarhus": "Aarhus Centrum",
        "station_action_dep": "Se afgangstavle",
        "station_action_plan": "Rejs herfra",
        "station_id": "ID",
        "station_coords": "Koordinater",
        
        # Favorites
        "fav_title": "Favoritter og historik",
        "fav_subtitle": "",
        "fav_stations_title": "Stationer",
        "fav_trips_title": "Ruter",
        "fav_history_title": "Historik",
        "fav_empty": "Ingen favoritter endnu",
        "fav_history_empty": "Ingen historik endnu",
        "fav_remove": "Fjern",
        "fav_go": "Søg",
        "fav_clear_history": "Ryd",
        
        # Settings
        "settings_title": "Indstillinger",
        "settings_subtitle": "",
        "settings_api_group": "API",
        "settings_api_key_label": "API-nøgle (accessId)",
        "settings_api_key_placeholder": "Indsæt accessId...",
        "settings_api_key_desc": "Rejseplanen API 2.0 accessId (fra labs.rejseplanen.dk)",
        "settings_base_url_label": "Basis-URL",
        "settings_base_url_desc": "Standard: https://www.rejseplanen.dk/api",
        "settings_test_conn_btn": "Test",
        "settings_mock_fallback_label": "Offline demo-data",
        "settings_mock_fallback_desc": "Brug demo-data hvis offline eller uden nøgle",
        "settings_labs_link_btn": "Hent API-nøgle (labs.rejseplanen.dk) ↗",
        "settings_appearance_group": "Udseende",
        "settings_lang_label": "Sprog",
        "settings_theme_label": "Tema",
        "theme_auto": "Følg system",
        "theme_light": "Lyst",
        "theme_dark": "Mørkt",
        "settings_about_group": "Om",
        "settings_about_desc": "RejseNu - App til kollektiv trafik i Danmark.",
        "settings_about_author": "Forfatter: gwj0323",
        "settings_save_btn": "Gem",
        "settings_saved_msg": "Gemt",
        
        # Common
        "loading": "Henter...",
        "error": "Fejl",
        "success": "Succes",
        "info": "Info",
        "mock_badge": "Demo",
        "live_badge": "Live",
        "conn_ok": "Forbindelse godkendt (HTTP 200 OK)",
        "conn_fail": "Forbindelse mislykkedes: ",
        "conn_no_key": "Indtast venligst en accessId først.",
        "saved_to_fav": "Gemt i favoritter.",
        "already_in_fav": "Allerede i favoritter.",
        "diag_key_label": "API-nøgle",
        "diag_key_configured": "Konfigureret ({masked})",
        "diag_key_missing": "Ikke konfigureret",
        "diag_mode_label": "Tilstand",
        "diag_mode_mock": "Demo",
        "diag_mode_live_fallback": "Live API (med demo-fallback)",
        "diag_mode_live_strict": "Live API",
        "diag_conn_label": "Status",
        "diag_conn_ok_short": "Normal (200 OK)",
        "diag_conn_none": "Ikke testet"
    }
}

class I18n:
    _listeners: List[Callable[[], None]] = []

    @classmethod
    def set_language(cls, lang: str):
        config.language = lang
        cls.notify_change()

    @classmethod
    def get_current_lang(cls) -> str:
        lang = config.language
        if lang not in TRANSLATIONS:
            return "zh_CN"
        return lang

    @classmethod
    def t(cls, key: str, **kwargs) -> str:
        lang = cls.get_current_lang()
        text = TRANSLATIONS.get(lang, {}).get(key)
        if text is None:
            text = TRANSLATIONS.get("en_US", {}).get(key, TRANSLATIONS.get("zh_CN", {}).get(key, key))
        if kwargs:
            try:
                return text.format(**kwargs)
            except Exception:
                return text
        return text

    @classmethod
    def add_listener(cls, callback: Callable[[], None]):
        if callback not in cls._listeners:
            cls._listeners.append(callback)

    @classmethod
    def remove_listener(cls, callback: Callable[[], None]):
        if callback in cls._listeners:
            cls._listeners.remove(callback)

    @classmethod
    def notify_change(cls):
        for listener in list(cls._listeners):
            try:
                listener()
            except Exception as e:
                print(f"[I18n] Error in listener: {e}")

def t(key: str, **kwargs) -> str:
    return I18n.t(key, **kwargs)
