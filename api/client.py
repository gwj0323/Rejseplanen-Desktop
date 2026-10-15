import requests
import datetime
import re
from typing import List, Dict, Any, Tuple, Optional
from config import config
from api.mock_data import (
    search_mock_stations,
    get_mock_station_by_id,
    get_mock_departures,
    get_mock_arrivals,
    get_mock_trips
)

def _ensure_list(item: Any) -> list:
    """Ensure element is a list, handling HAFAS single-object vs array XML-JSON mapping."""
    if item is None:
        return []
    if isinstance(item, list):
        return item
    return [item]

def _format_time_str(t_str: str) -> str:
    """Format time string like '11:18:00' or '11:18' to 'HH:MM'."""
    if not t_str:
        return ""
    parts = str(t_str).strip().split(":")
    if len(parts) >= 2:
        return f"{parts[0]:0>2}:{parts[1]:0>2}"
    return str(t_str)

def _normalize_date_str(d_str: Optional[str]) -> Optional[str]:
    """Convert any date format (e.g. 13.10.26, 13.10.2026) to YYYY-MM-DD required by API 2.0."""
    if not d_str:
        return None
    d_str = str(d_str).strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}$", d_str):
        return d_str
    m = re.match(r"^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$", d_str)
    if m:
        day, month, year = m.groups()
        if len(year) == 2:
            year = "20" + year
        return f"{year}-{int(month):02d}-{int(day):02d}"
    return d_str

def _parse_time_diff_min(time_str: str, rt_time_str: str) -> int:
    """Calculate minutes between scheduled time and real-time."""
    if not time_str or not rt_time_str:
        return 0
    t1_s = _format_time_str(time_str)
    t2_s = _format_time_str(rt_time_str)
    if t1_s == t2_s:
        return 0
    try:
        t1 = datetime.datetime.strptime(t1_s, "%H:%M")
        t2 = datetime.datetime.strptime(t2_s, "%H:%M")
        diff = int((t2 - t1).total_seconds() // 60)
        if diff < -720:
            diff += 1440
        elif diff > 720:
            diff -= 1440
        return max(0, diff)
    except Exception:
        return 0

def _parse_duration_minutes(duration_str: str) -> int:
    """Parse an ISO 8601 duration such as 'PT1H30M', 'P1DT2H15M' or 'PT45M'
    into total minutes. Returns 0 for empty or unparseable input."""
    if not duration_str:
        return 0
    m = re.match(
        r"^P(?!$)(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$",
        str(duration_str).strip().upper()
    )
    if not m:
        return 0
    days, hours, minutes, seconds = (int(g) if g else 0 for g in m.groups())
    return days * 1440 + hours * 60 + minutes + (1 if seconds >= 30 else 0)

class RejseplanenClient:
    """Client for Rejseplanen REST API 2.0 with automatic mock data fallback and detailed error reporting."""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Spor-Desktop/1.0",
            "Accept": "application/json"
        })
        self.last_error: Optional[str] = None
        self.last_status: str = "init"
        self._station_id_cache: Dict[str, str] = {
            "8600626": "A=1@O=København H@X=12565562@Y=55673063@U=86@L=8600626@p=1791796388@",
            "København H": "A=1@O=København H@X=12565562@Y=55673063@U=86@L=8600626@p=1791796388@",
            "8600646": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
            "8600030": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
            "Nørreport St.": "A=1@O=Nørreport St.@X=12571801@Y=55683455@U=86@L=8600646@p=1791796388@",
            "8603308": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
            "Kongens Nytorv": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
            "Kongens Nytorv St. (Metro)": "A=1@O=Kongens Nytorv St. (Metro)@X=12585231@Y=55679185@U=86@L=8603308@p=1791796388@",
            "8600858": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
            "8600649": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
            "CPH Lufthavn": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
            "Københavns Lufthavn, Kastrup St.": "A=1@O=CPH Lufthavn@X=12649162@Y=55629439@U=86@L=8600858@p=1791796388@",
            "8600650": "A=1@O=Østerport St.@X=12587784@Y=55692498@U=86@L=8600650@p=1791796388@",
            "Østerport St.": "A=1@O=Østerport St.@X=12587784@Y=55692498@U=86@L=8600650@p=1791796388@",
            "8600020": "A=1@O=Aalborg St.@X=9917044@Y=57043037@U=86@L=8600020@p=1791796388@",
            "Aalborg St.": "A=1@O=Aalborg St.@X=9917044@Y=57043037@U=86@L=8600020@p=1791796388@",
            "8600053": "A=1@O=Aarhus H@X=10204761@Y=56150444@U=86@L=8600053@p=1791796388@",
            "Aarhus H": "A=1@O=Aarhus H@X=10204761@Y=56150444@U=86@L=8600053@p=1791796388@",
            "8600512": "A=1@O=Odense St.@X=10386739@Y=55401778@U=86@L=8600512@p=1791796388@",
            "8600037": "A=1@O=Odense St.@X=10386739@Y=55401778@U=86@L=8600512@p=1791796388@",
            "Odense St.": "A=1@O=Odense St.@X=10386739@Y=55401778@U=86@L=8600512@p=1791796388@",
            "8600617": "A=1@O=Roskilde St.@X=12088550@Y=55639093@U=86@L=8600617@p=1791796388@",
            "Roskilde St.": "A=1@O=Roskilde St.@X=12088550@Y=55639093@U=86@L=8600617@p=1791796388@",
            "8600669": "A=1@O=Helsingør St.@X=12614167@Y=56033621@U=86@L=8600669@p=1791796388@",
            "Helsingør St.": "A=1@O=Helsingør St.@X=12614167@Y=56033621@U=86@L=8600669@p=1791796388@"
        }

    def _get_api_key(self) -> str:
        return config.api_key.strip()

    def _get_base_url(self) -> str:
        return config.base_url.strip()

    def _parse_error(self, resp: requests.Response) -> str:
        """Parse error message from Rejseplanen response (JSON or XML)."""
        try:
            data = resp.json()
            if isinstance(data, dict):
                code = data.get("errorCode", "")
                text = data.get("errorText", "")
                if text:
                    return f"{code}: {text}" if code else text
        except Exception:
            pass
        return resp.text[:180].replace("\n", " ").strip()

    def _resolve_station_hafas_id(self, query: str) -> str:
        """Resolve a station name or EVA number to the full HAFAS location ID string."""
        if not query or query.startswith("A="):
            return query
        if query in self._station_id_cache:
            return self._station_id_cache[query]
            
        key = self._get_api_key()
        if not key:
            return query
            
        try:
            resp = self.session.get(f"{self._get_base_url()}/location.name", params={
                "input": query,
                "accessId": key,
                "format": "json"
            }, timeout=6)
            if resp.status_code == 200:
                data = resp.json()
                raw_items = data.get("stopLocationOrCoordLocation", [])
                for item in raw_items:
                    stop = item.get("StopLocation") or item.get("CoordLocation")
                    if stop and "id" in stop:
                        full_id = stop["id"]
                        self._station_id_cache[query] = full_id
                        if "extId" in stop:
                            self._station_id_cache[stop["extId"]] = full_id
                        if "name" in stop:
                            self._station_id_cache[stop["name"]] = full_id
                        return full_id
        except Exception:
            pass
        return query

    def test_connection(self, api_key: Optional[str] = None, base_url: Optional[str] = None) -> Tuple[bool, str]:
        """Test API connection with the provided or configured accessId."""
        key = (api_key if api_key is not None else self._get_api_key()).strip()
        url = (base_url if base_url is not None else self._get_base_url()).rstrip("/")
        
        if not key:
            self.last_error = "API Key 为空"
            self.last_status = "error"
            return False, "API Key (accessId) 为空，请先在上方输入 Key！"
            
        endpoint = f"{url}/location.name"
        params = {
            "input": "København H",
            "accessId": key,
            "format": "json"
        }
        
        try:
            resp = self.session.get(endpoint, params=params, timeout=8)
            if resp.status_code == 200:
                self.last_error = None
                self.last_status = "ok"
                return True, "API 认证成功！Rejseplanen 官方服务器响应正常 (HTTP 200 OK)，accessId 有效可用。"
            else:
                err_text = self._parse_error(resp)
                msg = f"HTTP {resp.status_code} - {err_text}"
                self.last_error = msg
                self.last_status = "error"
                if resp.status_code == 401:
                    msg += "\n\n💡 提示：返回了 401 权限拒绝。可能原因：\n1. accessId 输入有误；\n2. 在 labs.rejseplanen.dk 申请的新账号仍在人工审核中 (Pending)；\n3. 账号权限尚未分配 API 2.0。"
                return False, msg
        except requests.exceptions.RequestException as e:
            msg = f"网络请求失败: {str(e)}"
            self.last_error = msg
            self.last_status = "error"
            return False, msg

    def search_locations(self, query: str) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Search stations and addresses. Returns (results, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key:
            if config.mock_fallback:
                return search_mock_stations(query), True, None
            return [], False, "未配置 API Key"
            
        endpoint = f"{self._get_base_url()}/location.name"
        params = {
            "input": query,
            "accessId": key,
            "format": "json"
        }
        
        err_msg = None
        try:
            resp = self.session.get(endpoint, params=params, timeout=7)
            if resp.status_code == 200:
                data = resp.json()
                results = []
                
                # Official API 2.0 format: stopLocationOrCoordLocation
                raw_items = data.get("stopLocationOrCoordLocation", [])
                for item in raw_items:
                    stop = item.get("StopLocation") or item.get("CoordLocation")
                    if stop:
                        full_id = stop.get("id", "")
                        ext_id = stop.get("extId", "")
                        name = stop.get("name", "")
                        if full_id and ext_id:
                            self._station_id_cache[ext_id] = full_id
                        if full_id and name:
                            self._station_id_cache[name] = full_id
                            
                        results.append({
                            "id": full_id or ext_id,
                            "extId": ext_id,
                            "name": name,
                            "lat": float(stop.get("lat", stop.get("y", 0))),
                            "lon": float(stop.get("lon", stop.get("x", 0))),
                            "types": ["ST"]
                        })
                        
                # Older format fallback
                if not results:
                    loc_list = data.get("LocationList") or data.get("locationList") or {}
                    stops = _ensure_list(loc_list.get("StopLocation") or loc_list.get("stopLocation") or [])
                    for s in stops:
                        results.append({
                            "id": str(s.get("id") or s.get("extId", "")),
                            "extId": str(s.get("extId", "")),
                            "name": s.get("name", ""),
                            "lat": float(s.get("lat", s.get("y", 0))),
                            "lon": float(s.get("lon", s.get("x", 0))),
                            "types": ["ST"]
                        })
                        
                if results:
                    self.last_error = None
                    self.last_status = "ok"
                    return results, False, None
            else:
                err_msg = f"HTTP {resp.status_code}: {self._parse_error(resp)}"
                self.last_error = err_msg
                self.last_status = "error"
        except Exception as e:
            err_msg = f"网络异常: {str(e)}"
            self.last_error = err_msg
            self.last_status = "error"
            
        if config.mock_fallback:
            return search_mock_stations(query), True, err_msg
        return [], False, err_msg

    def nearby_stops(self, lat: float, lon: float, max_no: int = 10) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Find nearby stops by coordinates. Returns (results, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key:
            if config.mock_fallback:
                mock_stations = list(search_mock_stations(""))
                mock_stations.sort(key=lambda s: (s["lat"] - lat)**2 + (s["lon"] - lon)**2)
                return mock_stations[:max_no], True, None
            return [], False, "未配置 API Key"
            
        endpoint = f"{self._get_base_url()}/location.nearbystops"
        params = {
            "originCoordLat": lat,
            "originCoordLong": lon,
            "maxNo": max_no,
            "accessId": key,
            "format": "json"
        }
        
        err_msg = None
        try:
            resp = self.session.get(endpoint, params=params, timeout=7)
            if resp.status_code == 200:
                data = resp.json()
                results = []
                raw_items = data.get("stopLocationOrCoordLocation", [])
                for item in raw_items:
                    stop = item.get("StopLocation") or item.get("CoordLocation")
                    if stop:
                        results.append({
                            "id": str(stop.get("id") or stop.get("extId", "")),
                            "extId": str(stop.get("extId", "")),
                            "name": stop.get("name", ""),
                            "lat": float(stop.get("lat", stop.get("y", 0))),
                            "lon": float(stop.get("lon", stop.get("x", 0))),
                            "distance": str(stop.get("dist", ""))
                        })
                if results:
                    self.last_error = None
                    self.last_status = "ok"
                    return results, False, None
            else:
                err_msg = f"HTTP {resp.status_code}: {self._parse_error(resp)}"
                self.last_error = err_msg
                self.last_status = "error"
        except Exception as e:
            err_msg = f"网络异常: {str(e)}"
            self.last_error = err_msg
            self.last_status = "error"
            
        if config.mock_fallback:
            mock_stations = list(search_mock_stations(""))
            mock_stations.sort(key=lambda s: (s["lat"] - lat)**2 + (s["lon"] - lon)**2)
            return mock_stations[:max_no], True, err_msg
        return [], False, err_msg

    def get_departure_board(
        self,
        station_id: str,
        date_str: Optional[str] = None,
        time_str: Optional[str] = None,
        use_bus: bool = True,
        use_train: bool = True,
        use_metro: bool = True
    ) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Fetch departure board for a station. Returns (departures, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key:
            if config.mock_fallback:
                return get_mock_departures(station_id), True, None
            return [], False, "未配置 API Key"
            
        # Resolve station ID if given name or non-HAFAS ID
        resolved_id = self._resolve_station_hafas_id(station_id)
        endpoint = f"{self._get_base_url()}/departureBoard"
        params = {
            "id": resolved_id,
            "accessId": key,
            "format": "json",
            "useBus": 1 if use_bus else 0,
            "useTrain": 1 if use_train else 0,
            "useMetro": 1 if use_metro else 0
        }
        if date_str:
            params["date"] = _normalize_date_str(date_str)
        if time_str:
            params["time"] = _format_time_str(time_str)
            
        err_msg = None
        try:
            resp = self.session.get(endpoint, params=params, timeout=8)
            if resp.status_code == 200:
                data = resp.json()
                raw_deps = data.get("Departure")
                if raw_deps is None:
                    board = data.get("DepartureBoard") or data.get("departureBoard") or {}
                    raw_deps = board.get("Departure") or board.get("departure") or []
                raw_deps = _ensure_list(raw_deps)
                
                departures = []
                for d in raw_deps:
                    sched_time = _format_time_str(d.get("time", ""))
                    rt_time = _format_time_str(d.get("rtTime", sched_time))
                    delay_min = _parse_time_diff_min(sched_time, rt_time)
                    
                    status = "normal"
                    if d.get("cancelled") in ("true", "1", True):
                        status = "cancelled"
                    elif delay_min >= 5:
                        status = "delayed"
                    elif delay_min > 0:
                        status = "minor_delay"
                        
                    prod = d.get("ProductAtStop") or {}
                    cat = prod.get("catOut") or d.get("type", "TOG")
                    
                    track = d.get("rtTrack") or d.get("track")
                    if not track and isinstance(d.get("rtPlatform"), dict):
                        track = d["rtPlatform"].get("text")
                    if not track:
                        track = "-"
                        
                    departures.append({
                        "name": d.get("name") or prod.get("name", "Transit"),
                        "type": cat,
                        "stop": d.get("stop", ""),
                        "time": sched_time,
                        "date": d.get("date", ""),
                        "rtTime": rt_time,
                        "rtDate": d.get("rtDate", d.get("date", "")),
                        "direction": d.get("direction", ""),
                        "track": track,
                        "rtTrack": track,
                        "delay": delay_min,
                        "status": status,
                        "messages": d.get("messages", "")
                    })
                if departures:
                    self.last_error = None
                    self.last_status = "ok"
                    return departures, False, None
            else:
                err_msg = f"HTTP {resp.status_code}: {self._parse_error(resp)}"
                self.last_error = err_msg
                self.last_status = "error"
        except Exception as e:
            err_msg = f"网络异常: {str(e)}"
            self.last_error = err_msg
            self.last_status = "error"
            
        if config.mock_fallback:
            return get_mock_departures(station_id), True, err_msg
        return [], False, err_msg

    def get_arrival_board(
        self,
        station_id: str,
        date_str: Optional[str] = None,
        time_str: Optional[str] = None
    ) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Fetch arrival board for a station. Returns (arrivals, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key:
            if config.mock_fallback:
                return get_mock_arrivals(station_id), True, None
            return [], False, "未配置 API Key"
            
        # Resolve station ID if given name or non-HAFAS ID
        resolved_id = self._resolve_station_hafas_id(station_id)
        endpoint = f"{self._get_base_url()}/arrivalBoard"
        params = {
            "id": resolved_id,
            "accessId": key,
            "format": "json"
        }
        if date_str:
            params["date"] = _normalize_date_str(date_str)
        if time_str:
            params["time"] = _format_time_str(time_str)
            
        err_msg = None
        try:
            resp = self.session.get(endpoint, params=params, timeout=8)
            if resp.status_code == 200:
                data = resp.json()
                raw_arrs = data.get("Arrival")
                if raw_arrs is None:
                    board = data.get("ArrivalBoard") or data.get("arrivalBoard") or {}
                    raw_arrs = board.get("Arrival") or board.get("arrival") or []
                raw_arrs = _ensure_list(raw_arrs)
                
                arrivals = []
                for a in raw_arrs:
                    sched_time = _format_time_str(a.get("time", ""))
                    rt_time = _format_time_str(a.get("rtTime", sched_time))
                    delay_min = _parse_time_diff_min(sched_time, rt_time)
                    
                    prod = a.get("ProductAtStop") or {}
                    cat = prod.get("catOut") or a.get("type", "TOG")
                    
                    track = a.get("rtTrack") or a.get("track")
                    if not track and isinstance(a.get("rtPlatform"), dict):
                        track = a["rtPlatform"].get("text")
                    if not track:
                        track = "-"
                        
                    arrivals.append({
                        "name": a.get("name") or prod.get("name", "Transit"),
                        "type": cat,
                        "stop": a.get("stop", ""),
                        "origin": a.get("origin", ""),
                        "time": sched_time,
                        "date": a.get("date", ""),
                        "rtTime": rt_time,
                        "track": track,
                        "rtTrack": track,
                        "delay": delay_min,
                        "direction": a.get("stop", ""),
                        "messages": a.get("messages", "")
                    })
                if arrivals:
                    self.last_error = None
                    self.last_status = "ok"
                    return arrivals, False, None
            else:
                err_msg = f"HTTP {resp.status_code}: {self._parse_error(resp)}"
                self.last_error = err_msg
                self.last_status = "error"
        except Exception as e:
            err_msg = f"网络异常: {str(e)}"
            self.last_error = err_msg
            self.last_status = "error"
            
        if config.mock_fallback:
            return get_mock_arrivals(station_id), True, err_msg
        return [], False, err_msg

    def get_trips(
        self,
        origin_id: str,
        dest_id: str,
        date_str: Optional[str] = None,
        time_str: Optional[str] = None,
        search_for_arrival: bool = False,
        use_bus: bool = True,
        use_train: bool = True,
        use_metro: bool = True
    ) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Find journey proposals. Returns (trips, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key:
            if config.mock_fallback:
                return get_mock_trips(origin_id, dest_id), True, None
            return [], False, "未配置 API Key"
            
        # Resolve short or EVA IDs to full HAFAS location ID
        orig_resolved = self._resolve_station_hafas_id(origin_id)
        dest_resolved = self._resolve_station_hafas_id(dest_id)
        
        endpoint = f"{self._get_base_url()}/trip"
        params = {
            "originId": orig_resolved,
            "destId": dest_resolved,
            "accessId": key,
            "format": "json",
            "searchForArrival": 1 if search_for_arrival else 0,
            "useBus": 1 if use_bus else 0,
            "useTrain": 1 if use_train else 0,
            "useMetro": 1 if use_metro else 0
        }
        
        norm_date = _normalize_date_str(date_str)
        if norm_date:
            params["date"] = norm_date
        if time_str:
            params["time"] = _format_time_str(time_str)
            
        err_msg = None
        try:
            resp = self.session.get(endpoint, params=params, timeout=15)
            if resp.status_code == 200:
                data = resp.json()
                raw_trips = data.get("Trip")
                if raw_trips is None:
                    trip_list = data.get("TripList") or data.get("tripList") or {}
                    raw_trips = trip_list.get("Trip") or trip_list.get("trip") or []
                raw_trips = _ensure_list(raw_trips)
                
                trips = []
                for idx, t in enumerate(raw_trips, start=1):
                    leg_list = t.get("LegList") or {}
                    legs_raw = _ensure_list(leg_list.get("Leg") or t.get("Leg") or [])
                    parsed_legs = []
                    
                    first_origin = None
                    last_dest = None
                    changes_count = 0
                    
                    for leg in legs_raw:
                        leg_type = leg.get("type", "TOG")
                        if leg_type != "WALK":
                            changes_count += 1
                            
                        prods = _ensure_list(leg.get("Product", []))
                        cat = prods[0].get("catOut") if prods else leg.get("category", leg_type)
                        
                        orig = leg.get("Origin") or leg.get("origin") or {}
                        dest = leg.get("Destination") or leg.get("destination") or {}
                        
                        if first_origin is None:
                            first_origin = orig
                        last_dest = dest
                        
                        parsed_legs.append({
                            "type": cat if leg_type != "WALK" else "WALK",
                            "name": leg.get("name", "Leg"),
                            "direction": leg.get("direction", ""),
                            "origin": {
                                "name": orig.get("name", ""),
                                "time": _format_time_str(orig.get("time", "")),
                                "date": orig.get("date", ""),
                                "track": orig.get("rtTrack") or orig.get("track", "-"),
                                "rtTime": _format_time_str(orig.get("rtTime", orig.get("time", "")))
                            },
                            "destination": {
                                "name": dest.get("name", ""),
                                "time": _format_time_str(dest.get("time", "")),
                                "date": dest.get("date", ""),
                                "track": dest.get("rtTrack") or dest.get("track", "-"),
                                "rtTime": _format_time_str(dest.get("rtTime", dest.get("time", "")))
                            },
                            "notes": leg.get("Notes", {}).get("text", "") if isinstance(leg.get("Notes"), dict) else ""
                        })
                        
                    dep_time = _format_time_str(first_origin.get("time", "00:00")) if first_origin else "00:00"
                    arr_time = _format_time_str(last_dest.get("time", "00:00")) if last_dest else "00:00"
                    
                    duration_min = _parse_time_diff_min(dep_time, arr_time)
                    if duration_min == 0 and "duration" in t:
                        duration_min = _parse_duration_minutes(str(t["duration"]))
                            
                    trips.append({
                        "idx": str(idx),
                        "duration_min": duration_min,
                        "dep_time": dep_time,
                        "arr_time": arr_time,
                        "changes": max(0, changes_count - 1),
                        "legs": parsed_legs
                    })
                    
                if trips:
                    self.last_error = None
                    self.last_status = "ok"
                    return trips, False, None
            else:
                err_msg = f"HTTP {resp.status_code}: {self._parse_error(resp)}"
                self.last_error = err_msg
                self.last_status = "error"
        except Exception as e:
            err_msg = f"网络异常: {str(e)}"
            self.last_error = err_msg
            self.last_status = "error"
            
        if config.mock_fallback:
            return get_mock_trips(origin_id, dest_id), True, err_msg
        return [], False, err_msg

    def get_journey_detail(self, ref_url_or_param: str) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        """Fetch journey detail intermediate stops using journeyDetail endpoint.
        Returns (stops, is_mock, error_msg)."""
        key = self._get_api_key()
        if not key or not ref_url_or_param or ref_url_or_param.startswith("mock"):
            return [], True, "未配置 API Key 或无经停信息"

        clean_ref = ref_url_or_param.strip()
        m_id = re.search(r'[?&]id=([^&]+)', clean_ref)
        m_ref = re.search(r'[?&]ref=([^&]+)', clean_ref)
        if m_id:
            clean_ref = m_id.group(1)
        elif m_ref:
            clean_ref = m_ref.group(1)
        elif clean_ref.startswith("ref="):
            clean_ref = clean_ref[4:]
        elif clean_ref.startswith("journeyDetail?"):
            clean_ref = clean_ref[len("journeyDetail?"):]

        import urllib.parse
        if "%" in clean_ref:
            try:
                clean_ref = urllib.parse.unquote(clean_ref)
            except Exception:
                pass

        base = self._get_base_url().rstrip('/')
        url = f"{base}/journeyDetail"
        params = {
            "id": clean_ref,
            "ref": clean_ref,
            "accessId": key,
            "format": "json"
        }
        try:
            resp = self.session.get(url, params=params, timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                j_obj = data.get("JourneyDetail") or data.get("journeyDetail") or data
                raw_stops = j_obj.get("Stops", {}).get("Stop") or j_obj.get("stops", {}).get("stop") or []
                stops_list = _ensure_list(raw_stops)
                parsed = []
                for s in stops_list:
                    if not isinstance(s, dict):
                        continue
                    name = s.get("name") or s.get("stop") or ""
                    if not name.strip():
                        continue
                    dep_t = _format_time_str(s.get("depTime") or s.get("time") or "")
                    arr_t = _format_time_str(s.get("arrTime") or "")
                    best_time = dep_t or arr_t
                    rt_dep_t = _format_time_str(s.get("rtDepTime") or s.get("rtTime") or "")
                    rt_arr_t = _format_time_str(s.get("rtArrTime") or "")
                    best_rt_time = rt_dep_t or rt_arr_t or best_time
                    track = s.get("rtTrack") or s.get("track") or s.get("rtDepTrack") or s.get("depTrack") or s.get("rtArrTrack") or s.get("arrTrack") or "-"
                    parsed.append({
                        "name": name,
                        "time": best_time,
                        "rt_time": best_rt_time,
                        "track": track,
                        "date": s.get("depDate") or s.get("arrDate") or s.get("date") or ""
                    })
                if parsed:
                    return parsed, False, None
            return [], False, f"HTTP {resp.status_code}: {self._parse_error(resp)}"
        except Exception as e:
            return [], False, f"网络异常: {str(e)}"

api_client = RejseplanenClient()
