/*
	GLT_fnc_cycleMarkerOverlay  [GLT] Goltred update - not part of the original Turret Enhanced by Fat_Lurch.
	Controls action "Cycle Camera Markers" (GLT_cycleMarkerOverlay):
		No markers -> My markers -> All map markers -> No markers ...
	skipping every mode the server doesn't allow (GLT_fnc_overlayModes).

	The key changes the player's own (client) value of GLT_MarkerOverlayMode and saves it to the profile, so
	Addon Options always shows the same choice.

	Server control:
		- "Enable Camera Marker Overlay" off (server-wide) -> the key does nothing (only a notice)
		- "Allow 'My Markers'" / "Allow 'All Map Markers'" off (server-wide) -> that mode is skipped;
		  with neither allowed the key does nothing
		- "Markers Shown" forced by the server / mission (CBA force) -> the key does nothing
	The settings are read at every press, so a change made by an admin mid-mission applies immediately.

	Returns: <BOOL> true if the mode changed
*/

private _names = ["No markers", "My markers", "All map markers"];

private _notify = {
	params ["_text"];
	"GLT_cycleMarkerOverlay" cutText [format ["Camera markers: %1", _text], "PLAIN DOWN", 0.3];
};

(call GLT_fnc_overlayModes) params ["_current", "_allowed"];

if (_allowed isEqualTo []) exitWith
{
	["disabled by the server"] call _notify;
	false
};
if (count _allowed < 2) exitWith
{
	[format ["%1 (no marker modes allowed by the server)", _names select _current]] call _notify;
	false
};
// Source in effect: "client" = the player's own value, "mission" / "server" = forced
if (("GLT_MarkerOverlayMode" call CBA_settings_fnc_priority) != "client") exitWith
{
	[format ["%1 (locked by server settings)", _names select _current]] call _notify;
	false
};

private _index = (_allowed find _current) max 0;
private _next = _allowed select ((_index + 1) mod (count _allowed));

// ["setting", value, priority, source, store in profile]
["GLT_MarkerOverlayMode", _next, 0, "client", true] call CBA_settings_fnc_set;
call GLT_fnc_buildOverlayList;

// Report what is actually in effect now
private _now = (call GLT_fnc_overlayModes) select 0;
[_names select _now] call _notify;

_now != _current
