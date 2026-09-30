/*
	GLT_fnc_overlayModes  [GLT] Goltred update - not part of the original Turret Enhanced by Fat_Lurch.
	Works out which camera-overlay modes are allowed and which one is in effect.

	Modes: 0 = No markers, 1 = My markers, 2 = All map markers

	Server-wide settings (CBA isGlobal = 1, players can't change them):
		GLT_MarkerOverlayShow      - overlay allowed at all
		GLT_MarkerOverlayAllowMine - mode 1 allowed
		GLT_MarkerOverlayAllowAll  - mode 2 allowed
	Player setting: GLT_MarkerOverlayMode - the chosen mode (also set by the cycle key).
	A chosen mode that isn't allowed falls back to the other allowed marker mode, else to 0.

	Returns: [_effectiveMode <NUMBER>, _allowedModes <ARRAY>]
		_allowedModes is [] when the overlay is disabled, otherwise [0] plus the allowed marker modes.
*/

if (!(missionNamespace getVariable ["GLT_MarkerOverlayShow", true])) exitWith {[0, []]};

private _allowed = [0];
if (missionNamespace getVariable ["GLT_MarkerOverlayAllowMine", true]) then {_allowed pushBack 1};
if (missionNamespace getVariable ["GLT_MarkerOverlayAllowAll", true]) then {_allowed pushBack 2};

private _chosen = missionNamespace getVariable ["GLT_MarkerOverlayMode", 1];
private _effective = if (_chosen in _allowed) then {_chosen} else {(_allowed - [0]) param [0, 0]};

[_effective, _allowed]
