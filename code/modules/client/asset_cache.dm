/*
Asset cache quick users guide:
Make a datum at the bottom of this file with your assets for your thing.
The simple subsystem will most like be of use for most cases.
Then call get_asset_datum() with the type of the datum you created and store the return
Then call .send(client) on that stored return value.
You can set verify to TRUE if you want send() to sleep until the client has the assets.
*/


// Amount of time(ds) MAX to send per asset, if this get exceeded we cancel the sleeping.
// This is doubled for the first asset, then added per asset after
#define ASSET_CACHE_SEND_TIMEOUT 7

//When sending mutiple assets, how many before we give the client a quaint little sending resources message
#define ASSET_CACHE_TELL_CLIENT_AMOUNT 8

/client
	var/list/cache = list() // List of all assets sent to this client by the asset cache.
	var/list/completed_asset_jobs = list() // List of all completed jobs, awaiting acknowledgement.
	var/list/sending = list()
	var/last_asset_job = 0 // Last job done.

//This proc sends the asset to the client, but only if it needs it.
//This proc blocks(sleeps) unless verify is set to false
/proc/send_asset(client/client, asset_name, verify = TRUE)
	if(!istype(client))
		if(ismob(client))
			var/mob/M = client
			if(M.client)
				client = M.client

			else
				return 0

		else
			return 0

	if(client.cache.Find(asset_name) || client.sending.Find(asset_name))
		return 0

	client << browse_rsc(asset_cache.cache[asset_name], asset_name)
	if(!verify || !winexists(client, "asset_cache_browser")) // Can't access the asset cache browser, rip.
		if (client)
			client.cache += asset_name
		return 1
	if (!client)
		return 0

	client.sending |= asset_name
	var/job = ++client.last_asset_job

	client << browse({"
	<script>
		window.location.href="?asset_cache_confirm_arrival=[job]"
	</script>
	"}, "window=asset_cache_browser")

	var/t = 0
	var/timeout_time = (ASSET_CACHE_SEND_TIMEOUT * client.sending.len) + ASSET_CACHE_SEND_TIMEOUT
	while(client && !client.completed_asset_jobs.Find(job) && t < timeout_time) // Reception is handled in Topic()
		sleep(1) // Lock up the caller until this is received.
		t++

	if(client)
		client.sending -= asset_name
		client.cache |= asset_name
		client.completed_asset_jobs -= job

	return 1

//This proc blocks(sleeps) unless verify is set to false
/proc/send_asset_list(client/client, list/asset_list, verify = TRUE)
	if(!istype(client))
		if(ismob(client))
			var/mob/M = client
			if(M.client)
				client = M.client

			else
				return 0

		else
			return 0

	var/list/unreceived = asset_list - (client.cache + client.sending)
	if(!unreceived || !unreceived.len)
		return 0
	if (unreceived.len >= ASSET_CACHE_TELL_CLIENT_AMOUNT)
		to_chat(client, "Sending Resources...")
	for(var/asset in unreceived)
		if (asset in asset_cache.cache)
			client << browse_rsc(asset_cache.cache[asset], asset)

	if(!verify || !winexists(client, "asset_cache_browser")) // Can't access the asset cache browser, rip.
		if (client)
			client.cache += unreceived
		return 1
	if (!client)
		return 0
	client.sending |= unreceived
	var/job = ++client.last_asset_job

	client << browse({"
	<script>
		window.location.href="?asset_cache_confirm_arrival=[job]"
	</script>
	"}, "window=asset_cache_browser")

	var/t = 0
	var/timeout_time = ASSET_CACHE_SEND_TIMEOUT * client.sending.len
	while(client && !client.completed_asset_jobs.Find(job) && t < timeout_time) // Reception is handled in Topic()
		sleep(1) // Lock up the caller until this is received.
		t++

	if(client)
		client.sending -= unreceived
		client.cache |= unreceived
		client.completed_asset_jobs -= job

	return 1

//This proc will download the files without clogging up the browse() queue, used for passively sending files on connection start.
//The proc calls procs that sleep for long times.
/proc/getFilesSlow(client/client, list/files, register_assets = TRUE)
	for(var/file in files)
		if (!client)
			break
		if (register_assets)
			debug_print("file: [file]")
			debug_print("files file: [files[file]]")
			register_asset(file, files[file])
		send_asset(client, file)
		sleep(0) //queuing calls like this too quickly can cause issues in some client versions

//This proc "registers" an asset, it adds it to the cache for further use, you cannot touch it from this point on or you'll fuck things up.
//if it's an icon or something be careful, you'll have to copy it before further use.
/proc/register_asset(asset_name, asset)
	asset_cache.cache[asset_name] = asset

//Generated names do not include file extention.
//Used mainly for code that deals with assets in a generic way
//The same asset will always lead to the same asset name
/proc/generate_asset_name(var/file)
	return "asset.[md5(fcopy_rsc(file))]"

// will return filename for cached atom icon or null if not cached
// can accept atom objects or types
/proc/getAtomCacheFilename(var/atom/A)
	if(!A || (!istype(A) && !ispath(A)))
		return
	var/filename = "[ispath(A) ? A : A.type].png"
	filename = sanitizeFileName(filename)
	if(asset_cache.cache[filename])
		return filename

//These datums are used to populate the asset cache, the proc "register()" does this.

//all of our asset datums, used for referring to these later
/var/global/list/asset_datums = list()

/datum/asset
	// All assets, "filename = file"
	var/list/assets = list()

	// If asset is trivial it's download will be transfered to end of queue
	var/isTrivial = TRUE
	var/registred = FALSE
	var/verify = FALSE

//get a assetdatum or make a new one
/proc/get_asset_datum(type)
	if (!(type in asset_datums))
		return new type()
	return asset_datums[type]

/datum/asset/New()
	asset_datums[type] = src
	register()

/datum/asset/proc/register()
	for(var/asset_name in assets)
		register_asset(asset_name, assets[asset_name])
	registred = TRUE

/datum/asset/proc/send(client)
	send_asset_list(client, assets, verify)

/datum/asset/proc/send_slow(client)
	getFilesSlow(client, assets, register_assets = FALSE)

// Check if all the assets were already sent
/datum/asset/proc/check_sent(client/C)
	if(length(assets & C.cache) == length(assets))
		return TRUE
	return FALSE


//For sending entire directories of assets
/datum/asset/directories
	var/list/dirs = list()

/datum/asset/directories/register()
	// Crawl the directories to find files.
	for (var/path in dirs)
		var/list/filenames = flist(path)
		for(var/filename in filenames)
			if(copytext(filename, length(filename)) != "/") // Ignore directories.
				if(fexists(path + filename))
					assets[filename] = fcopy_rsc(path + filename)
	..()


//If you don't need anything complicated.
/datum/asset/simple
	assets = list()
	verify = FALSE

/datum/asset/simple/register()
	for(var/asset_name in assets)
		register_asset(asset_name, assets[asset_name])

/datum/asset/simple/send(client)
	send_asset_list(client,assets,verify)

// For registering or sending multiple others at once
/datum/asset/group
	var/list/children = list()

/datum/asset/group/register()
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		if(!A.registred)
			A.register()

/datum/asset/group/send(client)
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		A.send(client)

/datum/asset/group/send_slow(client)
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		A.send_slow(client)

/datum/asset/group/check_sent(client)
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		A.check_sent(client)


//DEFINITIONS FOR ASSET DATUMS START HERE.
/datum/asset/directories/pda
	isTrivial =  TRUE
	dirs = list(
		"icons/pda_icons/",
	)

/datum/asset/directories/tgui
	isTrivial = FALSE
	dirs = list(
		// tgui-next
		"tgui-next/packages/tgui/public/",
		"tgui-next/packages/tgui/public/bundles/",
		"tgui-next/packages/tgui/public/images/",

		// font-awesome
		"html/font-awesome/webfonts/",
		"html/font-awesome/css/"
	)

/datum/asset/directories/nanoui
	isTrivial = FALSE
	dirs = list(
		"nano/js/",
		"nano/css/",
		"nano/images/",
		"nano/templates/",
		"nano/images/torch/",
		"nano/images/status_icons/",
		"nano/images/source/",
		"nano/images/modular_computers/",
		"nano/images/exodus/",
		"nano/images/example/"
	)

/*
	Asset cache
*/
var/decl/asset_cache/asset_cache = new()

/decl/asset_cache
	var/list/cache

/decl/asset_cache/New()
	..()
	cache = new

/proc/send_assets()
	// Creates and registers every asset datum
	for(var/type in subtypesof(/datum/asset) - list(/datum/asset/group, /datum/asset/directories))
		get_asset_datum(type)

	for(var/client/C in GLOB.clients)
		C.send_resources()

	return TRUE