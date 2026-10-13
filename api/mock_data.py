import datetime
from typing import List, Dict, Any

STATIONS = [
    {
        "id": "8600626",
        "name": "København H",
        "lat": 55.673063,
        "lon": 12.565562,
        "types": ["IC", "REG", "S", "MET", "BUS"],
        "desc": "Copenhagen Central Station"
    },
    {
        "id": "8600646",
        "name": "Nørreport St.",
        "lat": 55.683455,
        "lon": 12.571801,
        "types": ["S", "MET", "REG", "BUS"],
        "desc": "Denmark's busiest transport hub"
    },
    {
        "id": "8603308",
        "name": "Kongens Nytorv St. (Metro)",
        "lat": 55.679185,
        "lon": 12.585231,
        "types": ["MET", "BUS"],
        "desc": "Metro hub: M1, M2, M3, M4"
    },
    {
        "id": "8600858",
        "name": "CPH Lufthavn",
        "lat": 55.629439,
        "lon": 12.649162,
        "types": ["MET", "IC", "REG", "BUS"],
        "desc": "Copenhagen Airport Terminal 3"
    },
    {
        "id": "8600650",
        "name": "Østerport St.",
        "lat": 55.692498,
        "lon": 12.587784,
        "types": ["S", "MET", "REG", "IC", "BUS"],
        "desc": "Major interchange in Østerbro"
    },
    {
        "id": "8600053",
        "name": "Aarhus H",
        "lat": 56.150444,
        "lon": 10.204761,
        "types": ["IC", "REG", "BUS"],
        "desc": "Aarhus Central Station"
    },
    {
        "id": "8600512",
        "name": "Odense St.",
        "lat": 55.401778,
        "lon": 10.386739,
        "types": ["IC", "REG", "BUS"],
        "desc": "Funen transport hub"
    },
    {
        "id": "8600020",
        "name": "Aalborg St.",
        "lat": 57.043037,
        "lon": 9.917044,
        "types": ["IC", "REG", "BUS"],
        "desc": "North Jutland main station"
    },
    {
        "id": "8600617",
        "name": "Roskilde St.",
        "lat": 55.639093,
        "lon": 12.088550,
        "types": ["IC", "REG", "BUS"],
        "desc": "Historic cathedral city station"
    },
    {
        "id": "8600669",
        "name": "Helsingør St.",
        "lat": 56.033621,
        "lon": 12.614167,
        "types": ["REG", "BUS", "FER"],
        "desc": "Hamlet's Elsinore & ferry terminal"
    }
]

def search_mock_stations(query: str) -> List[Dict[str, Any]]:
    query = query.strip().lower()
    if not query:
        return STATIONS[:6]
    results = []
    for s in STATIONS:
        if query in s["name"].lower() or query in s.get("desc", "").lower() or query in s["id"]:
            results.append(s)
    return results

def get_mock_station_by_id(station_id: str) -> Dict[str, Any]:
    for s in STATIONS:
        if s["id"] == station_id:
            return s
    return STATIONS[0]

def get_mock_departures(station_id: str, base_time: datetime.datetime = None) -> List[Dict[str, Any]]:
    if base_time is None:
        base_time = datetime.datetime.now()
        
    station = get_mock_station_by_id(station_id)
    name = station["name"]
    
    templates = [
        {
            "name": "Metro M2",
            "type": "MET",
            "direction": "Lufthavnen (CPH Airport)",
            "offset_min": 2,
            "track": "1",
            "delay_min": 0,
            "messages": ""
        },
        {
            "name": "S-tog Line A",
            "type": "S",
            "direction": "Hillerød",
            "offset_min": 5,
            "track": "9",
            "delay_min": 2,
            "messages": "Mindre forsinkelse pga. signalfejl"
        },
        {
            "name": "InterCityLyn 29",
            "type": "IC",
            "direction": "Aalborg St.",
            "offset_min": 8,
            "track": "5",
            "delay_min": 0,
            "messages": ""
        },
        {
            "name": "Metro M3 Cityringen",
            "type": "MET",
            "direction": "København H via Nørreport",
            "offset_min": 11,
            "track": "2",
            "delay_min": 0,
            "messages": ""
        },
        {
            "name": "S-tog Line B",
            "type": "S",
            "direction": "Farum",
            "offset_min": 14,
            "track": "10",
            "delay_min": 4,
            "messages": "Forsinket 4 min"
        },
        {
            "name": "Bus 5C",
            "type": "BUS",
            "direction": "Herlev Hospital",
            "offset_min": 17,
            "track": "Stop B",
            "delay_min": 1,
            "messages": ""
        },
        {
            "name": "Regionaltog 1345",
            "type": "REG",
            "direction": "Helsingør St.",
            "offset_min": 21,
            "track": "4",
            "delay_min": 0,
            "messages": ""
        }
    ]
    
    departures = []
    for t in templates:
        dep_time = base_time + datetime.timedelta(minutes=t["offset_min"])
        rt_time = dep_time + datetime.timedelta(minutes=t["delay_min"])
        
        status = "normal"
        if t["delay_min"] >= 5:
            status = "delayed"
        elif t["delay_min"] > 0:
            status = "minor_delay"
            
        departures.append({
            "name": t["name"],
            "type": t["type"],
            "stop": name,
            "time": dep_time.strftime("%H:%M"),
            "date": dep_time.strftime("%d.%m.%y"),
            "rtTime": rt_time.strftime("%H:%M") if t["delay_min"] > 0 else dep_time.strftime("%H:%M"),
            "rtDate": rt_time.strftime("%d.%m.%y"),
            "direction": t["direction"],
            "track": t["track"],
            "rtTrack": t["track"],
            "delay": t["delay_min"],
            "status": status,
            "messages": t["messages"]
        })
        
    return departures

def get_mock_arrivals(station_id: str, base_time: datetime.datetime = None) -> List[Dict[str, Any]]:
    if base_time is None:
        base_time = datetime.datetime.now()
        
    station = get_mock_station_by_id(station_id)
    name = station["name"]
    
    templates = [
        {
            "name": "Metro M1",
            "type": "MET",
            "origin": "Vanløse St.",
            "offset_min": 3,
            "track": "2",
            "delay_min": 0
        },
        {
            "name": "S-tog Line E",
            "type": "S",
            "origin": "Køge St.",
            "offset_min": 6,
            "track": "10",
            "delay_min": 1
        },
        {
            "name": "InterCity 114",
            "type": "IC",
            "origin": "Aarhus H",
            "offset_min": 10,
            "track": "4",
            "delay_min": 5
        }
    ]
    
    arrivals = []
    for t in templates:
        arr_time = base_time + datetime.timedelta(minutes=t["offset_min"])
        rt_time = arr_time + datetime.timedelta(minutes=t["delay_min"])
        arrivals.append({
            "name": t["name"],
            "type": t["type"],
            "stop": name,
            "origin": t["origin"],
            "time": arr_time.strftime("%H:%M"),
            "date": arr_time.strftime("%d.%m.%y"),
            "rtTime": rt_time.strftime("%H:%M") if t["delay_min"] > 0 else arr_time.strftime("%H:%M"),
            "track": t["track"],
            "rtTrack": t["track"],
            "delay": t["delay_min"],
            "direction": name,
            "messages": ""
        })
    return arrivals

def get_mock_trips(origin_id: str, dest_id: str, base_time: datetime.datetime = None) -> List[Dict[str, Any]]:
    if base_time is None:
        base_time = datetime.datetime.now()
        
    orig_station = get_mock_station_by_id(origin_id)
    dest_station = get_mock_station_by_id(dest_id)
    
    orig_name = orig_station["name"]
    dest_name = dest_station["name"]
    
    trips = []
    t1_dep = base_time + datetime.timedelta(minutes=4)
    t1_arr = t1_dep + datetime.timedelta(minutes=16)
    trip1 = {
        "idx": "1",
        "duration_min": 16,
        "dep_time": t1_dep.strftime("%H:%M"),
        "arr_time": t1_arr.strftime("%H:%M"),
        "changes": 0,
        "legs": [
            {
                "type": "MET",
                "name": "Metro M2",
                "direction": dest_name,
                "origin": {
                    "name": orig_name,
                    "time": t1_dep.strftime("%H:%M"),
                    "date": t1_dep.strftime("%d.%m.%y"),
                    "track": "1",
                    "rtTime": t1_dep.strftime("%H:%M")
                },
                "destination": {
                    "name": dest_name,
                    "time": t1_arr.strftime("%H:%M"),
                    "date": t1_arr.strftime("%d.%m.%y"),
                    "track": "2",
                    "rtTime": t1_arr.strftime("%H:%M")
                },
                "notes": "Høj frekvens (High frequency)"
            }
        ]
    }
    trips.append(trip1)
    return trips
