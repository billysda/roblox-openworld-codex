--[[
	LensFlare, by gluGPU
	https://devforum.roblox.com/t/lens-flare-system-easily-usable-by-builders-or-scripters/4021857/31
	2025
	
	Version 1.2
	
	Changelog:
		1.1 - Optimized lens flare calculations, added configuration file, reduced default raycast amount.
			1.1.1 - Fixed emitters with no / zero ColorBlend being greyscale
		
		1.2 - Added attachment support, more sun flare behaviors, and more configuration settings. Improved color blending behavior
			  and implemented further optimizations.
	
	This is a standalone version of the lens flare effect from my upcoming anti-gravity game Aero Racing.
	The module uses an OOP approach to easily allow for multiple flares to be created and managed through scripts.
	If you're not savvy with scripting, you can also use CollectionService tags to manually add lens flares to parts.
	A lens flare is also automatically created for the sun and will decrease exposure when looking directly at sun.
	The sun flare also decreases in brightness when the sun sets and if Lighting.Brightness is low (configurable).
	
	
	
	# Getting Started
	Place the entire "LensFlare" folder in ReplicatedStorage, or the module will break.
	
	To add a lens flare to a part, tag it with "LensFlare" in its properties. On game start, the lens flare will be added.
	
	Lens flares can only be added to BaseParts (parts and mesh parts) and attachments.
	Support for more instances may be added in the future.
	
	Lens flares can also inherit the color from the part that they are parented to. For attachments, the color is set to white.
	
	To modify the behavior of the lens flare system, you can use the "Configuration" object.
	
	
	
	# Attributes
	When tagging parts with "LensFlare", you can also use attributes to modify the lens flare behavior.
		LensFlareDistance: the distance at which the lens flare will fully fade out.
		LensFlareStrength: the strength of the lens flare. NOTE: Will also affect exposure adjustment if used on sun flare part.
		LensFlareStyle: the style of lens flare. If not present, will default to "SmallLight". See Styles section.
		
		
	
	# Scripting API
	The module can be required in scripts and then instantiated with the "new" constructor.
	
	LensFlare.new(
		camera: the camera that the lens flare will test against. workspace.CurrentCamera works for this.
		flareStyle: the style of lens flare that will be created.
		part: the part that the flare will emanate from.
	)
	
	LensFlare.Destroy(self: LensFlare): destroys the lens flare
	
	LensFlare.Update(self: LensFlare): updates the lens flare.
	LensFlare already updates itself every frame, so not entirely necessary.
	
	
	
	# Styles
	There are two lens styles included with the package.
	
	Default emulates an anamorphic lens flare and is used for the default sun flare.
	SmallLight is a scaled down version of Default and should be fine for local lights.
	
	You can also create your own lens flare styles.
	Duplicate one of the folders under LensFlare.Assets and modify the ParticleEmitters to your liking.
	ONLY USE PARTICLE EMITTERS UNDER LENS FLARE STYLE FOLDERS.
	
	For more information on how to customize lens flare styles, see the devforum post:
	https://devforum.roblox.com/t/lens-flare-system-easily-usable-by-builders-or-scripters/4021857/31
	
	
	
	# Attribution
	Credit is not necessary, but is highly appreciated if given.
--]]