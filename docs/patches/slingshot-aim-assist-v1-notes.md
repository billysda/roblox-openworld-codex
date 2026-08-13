# Slingshot Aim Assist v1 notes

The real shot remains server-authoritative hitscan. The trajectory preview is therefore intentionally straight, not ballistic. The cosmetic egg is also changed to a fast straight flight so the visual matches the authoritative hit path.

Aim assist is soft lock, not hard teleport aim:
- RMB/L2 enters aim mode.
- nearest eligible Fox close to screen center is acquired.
- camera is pulled smoothly while aim is held.
- LMB/R2 independently charges and fires.
- no target information is trusted by the server; only origin/direction/charge are sent as before.
