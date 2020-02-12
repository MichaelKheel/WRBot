/*
v0.1 = Старт плагина
v0.2 = Скачивание WR файла через сокеты
v0.3 = После длительных попыток, скачивать файлы с сервера плохая затея, сокет слишком ограничен,
движок не дает скачивать быстрее, если ускорять скачивание, это приводит к краш сервера.
v0.4 = Проба с SQL версией. (Прошла успешно)
v0.5 = KZ Timer || Не прожимает старт в начале
v0.6 = Решил отказатся от Таймера, т.к. время будет не точным.
v0.7 = Проценты вместо таймера
v0.8 = Новое скачивание, include http2
v0.9 = Исправление зависания, если бота кикнуть.
v1.01 = Нормальный таймер
v1.02 = Скорость бота была сделана вычислением текущего FPS сервера
v1.03 = От начало демки, срезается часть фреймов, чтобы моделька начинала проигрывание не из текстур.
v1.04 = Добавлены конфиги
v1.05 = Исправлены неслышаемые шаги
v1.06 = Проверки на наличие спрайтов в папке и возможный precache
v1.07 = Исправлена функция получения времени, сложность в том, что при конвертации из строки в дробное число, появляется погрешность 0.19999
v1.08 = Убрано скачивание через http файл local.ini, вместо этого, реализовано функция добавление файла mysql.
v1.09 = Проверка лицензии
v1.10 = Контроль версии
v1.11 = Бот не реагирует на bhop blocki
v1.12 = Функция получения внешнего IP для проверки лицензии.
v1.13 = Country flag получает по потоковой передаче.'
v1.14 = Оптимизация кода + добавлен код вейза.
v1.15 = Переписан весь код. Добавлен разархиватор ввиде модуля созданный garey, скачивания архива напрямую с сайтов. И парсинг данных непосредственно из демки.
v1.16 = Потоковое получение лицензии, чтоб при старте сервера не было лага.
v1.17 = От первого лица, флаг не видно.
v1.18 = Игнорирование бхоп блоков + кнопка старта и финиша. + объединение в MySQL и nVault в один файл. // Оптимизация.
v1.19 = Фикс на дерганье бота на некоторых картах. Бот игнорирует весь урон, кроме урон от падения.
v1.20 = Проверка параметра sv_lan в случае с параметром 1, выводит сообщение ошибки. Исправление смерти бота.
v1.21 = Добавлена верификация по стиму для тех кто купил паблик бота для лан сервера, переделана запись в файл country даты. Сделан частичный рефакторинг кода.
v1.22 = Оптимизация Mysql. Новая БД, скорость чтение увеличено.
*/
#define nVault
//#define SQL
#define PUB
//#define LAN

#pragma tabsize 0
#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <sockets>
#include <sqlx_bot>
#include <colorchat>

#if defined nVault
	#include <AmxxArch>
	#include <curl>
#endif

#define PLUGIN "KZ[L]WRBOT"
#define VERSION "1.22"
#define AUTHOR "MichaelKheel"
#define SOCKET_SITE "test.kreedz.ru"
#define SOCKET_GET "/index.php"

//#define DEV_DEBUG

new Handle:g_SqlTuple
new Handle:SqlConnection
new g_Error[512]
new g_szMapName[32];
// Массивы для хранения данных
new Array:fPlayerAngle, Array:fPlayerKeys, Array:fPlayerVelo, Array:fPlayerOrigin;
// Для обратного отсчета
new g_timer;
// Timer
new Float:timer_time[33], bool:timer_started[33], bool:IsPaused[33], Float:g_pausetime[33], bool:bot_finish_use[33];
// переменные управления
new g_bot_start, g_bot_enable, g_bot_frame, wr_bot_id;
// Убирает наложение Hud
new SyncHudTimer, SyncHudBotTimer
// Массив для кнопок [0] - start / [1] - finish
new Trie:g_tButtons[2];
// Country Flag
#define CountryData "addons/amxmodx/data/local.ini"
new Local_ini, g_Bot_Icon_ent, url_sprite[64], url_sprite_xz[64];
// Полученные данные из базы
new WR_TIME[130], WR_NAME[130]
// Определенние nextthink
new Float:nExttHink = 0.009
// Первое вхождение на сервер (LAN или PUB verification STEAM)
new bool:firstspawn[33];
// Проверка сервер на sv_lan 1
new bool:b_CvarError = false;
// Верификация пользователя
new gl_verification[17];
// Квары
#if defined PUB
new country_flag;
#endif
new hud_message, timer_bot, timer_option, cooldown_startbot, update_timer, g_xc, g_yc, g_start_frame;
// Игнорирование бхоп блоков для бота
#define SetBhopBlocks(%1,%2)   %1[%2>>5] |=  1<<(%2 & 31)
#define GetBhopBlocks(%1,%2)   %1[%2>>5] &   1<<(%2 & 31)
new g_bBlocks[64]

#if defined DEV_DEBUG
new Float:flStartTime
#endif

#if defined nVault
#define NUM_THREADS 256

#pragma dynamic 32767 // Without this line will crash server!!

#define PEV_PDATA_SAFE    2

#define OFFSET_TEAM            114
#define OFFSET_DEFUSE_PLANT    193
#define HAS_DEFUSE_KIT        (1<<16)
#define OFFSET_INTERNALMODEL    126

new bool:g_Demos = false;

new iXJWRs, iCCWRs, iArchive;
new bool:bFoundDemo = false;
new iDemo_header_size;
new iArchiveName[256];
new iDemoName[256];
new iNavName[256];
new iFile;
new iParsedFile;
#endif

#if defined PUB
new verification, PlayServerIP[17], socketIP[17], bool:g_socket_check = false;
#endif

#if defined LAN
new bool:plugin_activated = false, bool:license = false
#endif

public plugin_precache()
{
	get_mapname(g_szMapName, sizeof(g_szMapName) - 1);
	strtolower(g_szMapName);

	#if defined PUB
		#if defined SQL
			country_flag_add()
		#endif

		#if defined nVault
			parsing_country("xj")
		#endif
	#endif

	new i;
	for(i = 0; i < sizeof(g_tButtons); i++)
		g_tButtons[i] = TrieCreate();

	new szStartTargets[][] = {
	"counter_start", "clockstartbutton", "firsttimerelay", "but_start",
	"counter_start_button", "multi_start", "timer_startbutton", "start_timer_emi", "gogogo"
	};

	for(i = 0; i < sizeof szStartTargets ; i++)
		TrieSetCell(g_tButtons[0], szStartTargets[i], i);

	new szFinishTargets[][] = {
	"counter_off", "clockstopbutton", "clockstop", "but_stop",
	"counter_stop_button", "multi_stop", "stop_counter", "m_counter_end_emi"
	};

	for (i = 0; i < sizeof szFinishTargets; i++)
		TrieSetCell(g_tButtons[1], szFinishTargets[i], i);

	new Ent = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
	set_pev(Ent, pev_classname, "BotThink");
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01 );
	register_forward( FM_Think, "fwd_Think", 1 );
	fPlayerAngle  = ArrayCreate( 2 );
	fPlayerOrigin = ArrayCreate( 3 );
	fPlayerVelo   = ArrayCreate( 3 );
	fPlayerKeys   = ArrayCreate( 1 );
}

public plugin_init ()
{
	register_plugin( PLUGIN, VERSION, AUTHOR);

	hud_message = register_cvar("hud_message","1");
	timer_bot = register_cvar("timer_bot","1");
	timer_option = register_cvar("timer_option","1");
	cooldown_startbot = register_cvar("cooldown_startbot","5");
	update_timer = register_cvar("update_timer","1");
	g_xc = register_cvar("x_coordinates","-1.0");
	g_yc = register_cvar("y_coordinates","0.35");
	g_start_frame = register_cvar("delete_frame","0");

	#if defined PUB
	country_flag = register_cvar("country_flag","1");
	verification = register_cvar("verification_method", "IP");
	#endif

	#if defined LAN
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_P", true);
	register_clcmd("say /playwr", "StartWatchWR");
	register_clcmd("say /stopwr", "Stop");
	#endif
	// Бессмертие бота
	RegisterHam(Ham_TakeDamage, "player", "BotAfterDamage", 0)
	// Регистрация команды для бота
	register_concmd("amx_wrbotmenu", "ClCmd_ReplayMenu");
	//Подключение файла конфига
	new kreedz_cfg[128], ConfigDir[64]
	get_configsdir(ConfigDir, 64)
	formatex(kreedz_cfg,128,"%s/wrbot.cfg", ConfigDir)

	if(file_exists(kreedz_cfg))
	{
		server_cmd("exec %s",kreedz_cfg)
		server_exec()
	}
	else
	{
		server_print("[WR_BOT] Config file is not connected, please check.")
	}

	#if defined PUB
	get_pcvar_string(verification, gl_verification, charsmax( gl_verification ) );
	if(equali(gl_verification, "STEAM")) RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_P", true);
	if(get_pcvar_num(country_flag)) register_forward(FM_AddToFullPack, "addToFullPack", 1)
	#endif

		// Таймер бота
		if(get_pcvar_num(timer_bot) == 1)
		{
			if(get_pcvar_num(update_timer) == 1)
			{
				new iTimer = create_entity("info_target")
				entity_set_float(iTimer, EV_FL_nextthink, get_gametime() + 0.08)
				entity_set_string(iTimer, EV_SZ_classname, "hud_update")
				register_think("hud_update", "timer_task")
			}
			else if(get_pcvar_num(update_timer) == 2)
			{
				set_task(0.1,"timer_task",0,_,_,"b")
			}
			else if(get_pcvar_num(update_timer) == 3)
			{
				new iTimerEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString , "info_target"))
				set_pev(iTimerEnt, pev_classname, "kz_time_think")
				set_pev(iTimerEnt, pev_nextthink, get_gametime() + 1.0)
			}
		}

	// Hud синхронизация
	SyncHudTimer = CreateHudSyncObj()
	SyncHudBotTimer = CreateHudSyncObj()
	// SQL Connect
	g_SqlTuple = SQL_MakeDbTuple(SQL_HOST, SQL_USER, SQL_PASS, SQL_DB);
	plugin_sql()
}

public plugin_sql()
{
	new ErrorCode
	SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,511)

	if(!SqlConnection)
		return pause("a")

	return PLUGIN_CONTINUE
}

public plugin_cfg()
{
	#if defined PUB
		if(equali(gl_verification, "IP"))
		{
			get_user_ip(0, PlayServerIP, 16, 1);
			SQL_Check_license(PlayServerIP);
		}
	#endif

	SetTouch();
}

#if defined PUB
public Ham_PlayerSpawn_P(id)
{
	if(is_user_localhost(id) && is_user_alive(id) && !is_user_bot(id) && firstspawn[id])
	{
		new steamid[32]
		get_user_authid(id, steamid, charsmax(steamid))

		firstspawn[id] = false;
		SQL_Check_license(steamid)
		//set_task(0.5, "plugin_info", id,_,_,"b")
	}
}

public GetTehRealIp( szOutPut[ ], iLen )
{
	new iReturn, iSocket = socket_open( SOCKET_SITE, 80, SOCKET_TCP, iReturn );

	if( iReturn > 0 )
		return 0;

	new sendbuffer[512]
	format(sendbuffer, 511, "GET %s HTTP/1.1^nHost:%s^r^n^r^n", SOCKET_GET, SOCKET_SITE)
	socket_send( iSocket, sendbuffer, 511)
	new szBuffer[ 512 ];
	socket_recv( iSocket, szBuffer, 511 );

	if( !szBuffer[ 0 ] ) {
		socket_close( iSocket );

		return 0;
	}

	iReturn = contain( szBuffer, "IP: " ) + 4;

	if( iReturn > 4 )
		formatex( szOutPut, iLen, szBuffer[ iReturn ] );

	socket_close( iSocket );

	return ( iReturn > 0 );
}
#endif

public SQL_Check_license(value[])
{
	#if defined DEV_DEBUG
	flStartTime = get_gametime();
	#endif

	trim(value);
	new createinto[512]

	#if defined LAN
		formatex(createinto, sizeof createinto - 1, "SELECT * FROM wrbot_user WHERE steamid='%s' AND lan='1'", value)
	#endif

	#if defined PUB
		if(equali(gl_verification, "IP"))
			formatex(createinto, sizeof createinto - 1, "SELECT * FROM wrbot_user WHERE ip_p='%s' AND pub='1'", value)
		else if(equali(gl_verification, "STEAM"))
			formatex(createinto, sizeof createinto - 1, "SELECT * FROM wrbot_user WHERE steamid='%s' AND pub='1'", value)
	#endif

	SQL_ThreadQuery(g_SqlTuple, "SQL_Check_license_Handle", createinto)
}

public SQL_Check_license_Handle(failstate, Handle:hQuery, error[], errcode, cData[], iSize, Float:fQueueTime)
{
	if( failstate == TQUERY_CONNECT_FAILED )
	{
		set_fail_state("Could not connect to database.");
	}
	else if( failstate == TQUERY_QUERY_FAILED )
	{
		set_fail_state("Query failed.");
	}
	else if( errcode )
	{
		log_amx("Error on query: %s", error);
	}
	else
	{
		if (SQL_NumResults(hQuery))
		{
			#if defined LAN
				new servername = SQL_FieldNameToNum(hQuery, "name")
			#else
				new servername = SQL_FieldNameToNum(hQuery, "server_name")
			#endif

			new version = SQL_FieldNameToNum(hQuery, "version")
			new sz_ServerName[128], Float:sz_version;
			new Float:f_ver = str_to_float(VERSION)

			while( SQL_MoreResults(hQuery) )
			{
				SQL_ReadResult(hQuery, servername, sz_ServerName, charsmax(sz_ServerName))
				SQL_ReadResult(hQuery, version, sz_version)
				SQL_NextRow(hQuery)
			}
			server_print("[WR-BOT v%s] Hi %s. Check the license was successful.", VERSION, sz_ServerName)
			if(sz_version > f_ver)
			{
				server_print("*************************************************************************")
				server_print("[WR-BOT] There is a new version, please download and update the plugin!")
				server_print("*************************************************************************")
			}
			#if defined SQL
				SQL_QUERY();

				#if defined PUB
					if(get_pcvar_num(country_flag)) SQL_Country();
				#endif
			#endif

			#if defined nVault
				announce();
			#endif

			#if defined LAN
				license = true;
			#endif
		}
		else
		{
			#if defined PUB
			if(!g_socket_check)
			{
				GetTehRealIp( socketIP, 16 );
				server_print("External IP Server: %s", socketIP)
				SQL_Check_license(socketIP)
				g_socket_check = true;
			}
			else
			{
				server_print("[WR-BOT] You did not buy a license for the plugin, or have not confirmed your profile.")
				return pause("a")
			}
			#endif

			#if defined LAN
			if(b_CvarError)
				ColorChat(0, RED,  "^4[WR-BOT ^3v%s^1]^1 ERROR ... Switch the setting to -> ^3sv_lan 0 ^1", VERSION);
			else
				ColorChat(0, RED, "^4[WR-BOT ^3v%s^1]^1 You did not buy a license for the plugin, or have not confirmed your profile.", VERSION);
			#endif
		}
	}

	SQL_FreeHandle(hQuery)
	return PLUGIN_CONTINUE
}

public BotAfterDamage ( victim, weapon, attacker, Float:damage, damagebits )
{
	if (is_user_bot(victim) || is_user_bot(attacker))
		if ( damagebits & DMG_FALL )
			set_pev(wr_bot_id,pev_health,9999.0)
	else
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public Ham_ButtonUse( id )
{
	new Float:origin[3];
	pev( id, pev_origin, origin );
	new ent = -1;
	while ( (ent = find_ent_in_sphere( ent, origin, 100.0 ) ) != 0 )
	{
		new classname[32];
		pev( ent, pev_classname, classname, charsmax( classname ) );

			new Float:eorigin[3];
			get_brush_entity_origin( ent, eorigin );
			static Float:Distance[2];
			new szTarget[32];
			pev( ent, pev_target, szTarget, 31 );

			if ( TrieKeyExists( g_tButtons[0], szTarget ) )
			{
				if( !g_bot_start && get_pcvar_num(g_start_frame) != 0)
					g_bot_start = g_bot_frame - get_pcvar_num(g_start_frame);

				if( g_bot_start < 0 )
					g_bot_start = 0;

				if ( vector_distance( origin, eorigin ) >= Distance[0] )
				{
					timer_time[id] = get_gametime()
					IsPaused[id] = false
					timer_started[id] = true
					bot_finish_use[id] = false;
				}
				Distance[0] = vector_distance( origin, eorigin );
			}
			if ( TrieKeyExists( g_tButtons[1], szTarget ) )
			{
				if ( vector_distance( origin, eorigin ) >= Distance[1] )
				{
					if (!bot_finish_use[id])
					{
						if(timer_started[id])
						{
							if(get_pcvar_num(cooldown_startbot) == 0)
								Start_Bot();
							else
								StartCountDown();
						}
						timer_started[id] = false;
						bot_finish_use[id] = true;
					}
				}
				Distance[1] = vector_distance( origin, eorigin );
			}
	}
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ TIMER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
public timer_task(iTimer)
{
	new Dead[32], deadPlayers
	get_players(Dead, deadPlayers, "bh")
	for(new i=0;i<deadPlayers;i++)
	{
		new specmode = pev(Dead[i], pev_iuser1)
		if(specmode == 2 || specmode == 4)
		{
			new target = pev(Dead[i], pev_iuser2)
			if(is_user_alive(target))
			{
				if (timer_started[target] && target == wr_bot_id)
				{
					new Float:kreedztime = get_gametime() - (IsPaused[target] ? get_gametime() - g_pausetime[target] : timer_time[target])
					new imin = floatround( kreedztime / 60.0, floatround_floor );
					new isec = floatround( kreedztime - imin * 60, floatround_floor );
					new mili = floatround( ( kreedztime - ( imin * 60 + isec ) ) * 100, floatround_floor );
					if(get_pcvar_num(timer_option) == 1)
					{
						client_print(Dead[i], print_center , "[ %02i:%02i.%02i ]",imin, isec, mili, IsPaused[target] ? "| *Paused*" : "")
					}
					else if(get_pcvar_num(timer_option) == 2)
					{
						set_hudmessage(255, 255, 255, get_pcvar_float(g_xc), get_pcvar_float(g_yc), 0, 0.0, 1.0, 0.0, 0.0)
						ShowSyncHudMsg(Dead[i], SyncHudBotTimer, "[ %02i:%02i.%02i ]",imin, isec, mili, IsPaused[target] ? "| *Paused*" : "")
					}
				}
				else if (!timer_started[target] && target == wr_bot_id)
				{
					client_print(Dead[i], print_center, "")
				}
			}
		}
	}

	if(get_pcvar_num(update_timer) == 1) entity_set_float(iTimer, EV_FL_nextthink, get_gametime() + 0.07)
}

public Pause()
{
	if(!IsPaused[wr_bot_id])
	{
		g_pausetime[wr_bot_id] = get_gametime() - timer_time[wr_bot_id]
		timer_time[wr_bot_id] = 0.0
		IsPaused[wr_bot_id] = true
		g_bot_enable = 2;
	}
	else
	{
		if(timer_started[wr_bot_id])
		{
			timer_time[wr_bot_id] = get_gametime() - g_pausetime[wr_bot_id]
		}
		IsPaused[wr_bot_id] = false
		g_bot_enable = 1;
	}
}

public fwd_Think( iEnt )
{
	if ( !pev_valid( iEnt ) )
		return(FMRES_IGNORED);

	static className[32];
	pev( iEnt, pev_classname, className, 31 );

#if defined nVault
	if ( equal( className, "DemThink" ) )
	{
		static bool:Finished;
		for(new i = 0; i < NUM_THREADS; i++)
		{
			if(ReadFrames(iFile))
			{
				Finished = true;
				break;
			}
		}

		if(Finished)
		{
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
			fclose( iFile );
			delete_file( iDemoName);
			LoadParsedInfo( iNavName );
		}
		else
		{
			set_pev( iEnt, pev_nextthink, get_gametime() + 0.001 )
		}
	}
	if ( equal( className, "NavThink" ) )
	{
		static bool:Finished;
		for(new i = 0; i < NUM_THREADS; i++)
		{
			if(!ReadParsed(iEnt))
			{
				Finished = true;
				break;
			}
		}

		if(Finished)
		{
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
			//fclose( iFile );
			delete_file(iNavName);
			set_task( 2.0, "StartCountDown");
		}
	}
#endif

	if(equal(className, "kz_time_think"))
	{
		timer_task(1)
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.08)
	}

	if ( equal( className, "BotThink" ) )
	{
		BotThink( wr_bot_id );
		set_pev( iEnt, pev_nextthink, get_gametime() + nExttHink );
	}

	return(FMRES_IGNORED);
}

public BotThink( id )
{
	static Float:ViewOrigin[3], Float:ViewAngle[3], Float:ViewVelocity[3], ViewKeys;

	static Float:last_check, Float:game_time, nFrame;
	game_time = get_gametime();

	if( game_time - last_check > 1.0 )
	{
		if (nFrame < 100)
			nExttHink = nExttHink - 0.0001
		else if (nFrame > 100)
			nExttHink = nExttHink + 0.0001

		nFrame = 0;
		last_check = game_time;
	}

	if(g_bot_enable == 1 && wr_bot_id)
	{
		g_bot_frame++;
		if ( g_bot_frame < ArraySize( fPlayerAngle ) )
		{
			ArrayGetArray( fPlayerOrigin, g_bot_frame, ViewOrigin );
			ArrayGetArray( fPlayerAngle, g_bot_frame, ViewAngle );
			ArrayGetArray( fPlayerVelo, g_bot_frame, ViewVelocity)
			ViewKeys = ArrayGetCell( fPlayerKeys, g_bot_frame );

			if(ViewKeys&IN_ALT1) ViewKeys|=IN_JUMP;
			if(ViewKeys&IN_RUN)  ViewKeys|=IN_DUCK;

			if(ViewKeys&IN_RIGHT)
			{
				engclient_cmd(id, "weapon_usp");
				ViewKeys&=~IN_RIGHT;
			}
			if(ViewKeys&IN_LEFT)
			{
				engclient_cmd(id, "weapon_knife");
				ViewKeys&=~IN_LEFT;
			}
			if ( ViewKeys & IN_USE )
			{
				Ham_ButtonUse( id );
				ViewKeys &= ~IN_USE;
			}

			engfunc(EngFunc_RunPlayerMove, id, ViewAngle, ViewVelocity[0], ViewVelocity[1], 0.0, ViewKeys, 0, 10);
			set_pev( id, pev_v_angle, ViewAngle );
			ViewAngle[0] /= -3.0;
			set_pev(id, pev_velocity, ViewVelocity);
			set_pev(id, pev_angles, ViewAngle);
			set_pev(id, pev_origin, ViewOrigin);
			set_pev(id, pev_button, ViewKeys );

			if( pev( id, pev_gaitsequence ) == 4 && ~pev( id, pev_flags ) & FL_ONGROUND )
				set_pev( id, pev_gaitsequence, 6 );

			if(nFrame == ArraySize( fPlayerAngle ) - 1)
			{
				if(get_pcvar_num(cooldown_startbot) == 0)
					Start_Bot();
				else
					StartCountDown();
			}

		} else  {
			g_bot_frame = 0;
		}
	}
	nFrame++;
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ SETTING MENU ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

public ClCmd_ReplayMenu(id)
{
	if(!access(id,ADMIN_MENU))
		return PLUGIN_HANDLED;

	new title[512]
	formatex(title, 500, "\wSetting Bot Replay Menu^nName: \y%s\w^nRecord: \y%s", WR_NAME, WR_TIME)
	new menu = menu_create(title, "ReplayMenu_Handler")
	menu_additem(menu, "Start/Reset", "1");

	if(get_pcvar_num(timer_bot))
	{
		if (g_bot_enable == 1)
		   menu_additem(menu, "Pause^n", "2");
		else
			menu_additem(menu, "Play^n", "2");
	}
	else
	{
		menu_additem(menu, "\dPause - disabled ^n", "2");
	}
	menu_additem(menu, "Kick bot", "3");
	menu_display(id, menu, 0);

	return PLUGIN_HANDLED
}

public ReplayMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;

	switch(item)
	{
		case 0:
		{
			if(!wr_bot_id)
				StartCountDown()
			else
				Start_Bot()
		}
		case 1: if(get_pcvar_num(timer_bot)) Pause();
		case 2:
		{
			if(wr_bot_id)
				server_cmd("kick #%d", get_user_userid(wr_bot_id))
		}
	}
	ClCmd_ReplayMenu(id);
	return PLUGIN_HANDLED;
}

Create_Bot()
{
	new txt[64]
	formatex(txt, charsmax(txt), "[WR] %s %s", WR_NAME, WR_TIME);
	new id = engfunc(EngFunc_CreateFakeClient, txt);
	if(pev_valid(id))
	{
		set_user_info(id, "rate", "10000");
		set_user_info(id, "cl_updaterate", "60");
		set_user_info(id, "cl_cmdrate", "60");
		set_user_info(id, "cl_lw", "1");
		set_user_info(id, "cl_lc", "1");
		set_user_info(id, "cl_dlmax", "128");
		set_user_info(id, "cl_righthand", "1");
		set_user_info(id, "_vgui_menus", "0");
		set_user_info(id, "_ah", "0");
		set_user_info(id, "dm", "0");
		set_user_info(id, "tracker", "0");
		set_user_info(id, "friends", "0");
		set_user_info(id, "*bot", "1");
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT);
		set_pev(id, pev_colormap, id);

		dllfunc(DLLFunc_ClientConnect, id, "WR BOT", "127.0.0.1");
		dllfunc(DLLFunc_ClientPutInServer, id);

		cs_set_user_team(id, CS_TEAM_CT);
		cs_set_user_model(id, "sas");

		ham_give_weapon(id,"weapon_knife")
		ham_give_weapon(id,"weapon_usp")
		cs_set_user_bpammo(id, CSW_USP, 250)

		#if defined PUB
			if(get_pcvar_num(country_flag)) create_bot_icon(id)
		#endif

		if(!is_user_alive(id)) dllfunc(DLLFunc_Spawn, id);

		return id;
	}
	return 0;
}

//Начало отсчета
public StartCountDown()
{
	if(!wr_bot_id)
		wr_bot_id = Create_Bot();

	g_timer = get_pcvar_num(cooldown_startbot);
	set_task(1.0, "Show");
}

public Show()
{
	g_timer--;
	set_hudmessage(255, 255, 255, 0.05, 0.2, 0, 6.0, 1.0)

	if(g_timer && g_timer >= 0)
	{
		if(get_pcvar_num(hud_message)) ShowSyncHudMsg(0, SyncHudTimer, "Bot WR run through: %i sec", g_timer);
		set_task(1.0, "Show");
	}
	else {
		if(get_pcvar_num(hud_message)) ShowSyncHudMsg(0, SyncHudTimer, "Bot has started");
		g_bot_enable = 1;
		Start_Bot()
	}
}

Start_Bot()
{
	g_bot_frame = g_bot_start;
	timer_started[wr_bot_id] = false
}

public client_disconnect( id )
{
	if( id == wr_bot_id )
	{
		timer_time[id] = 0.0
		IsPaused[wr_bot_id] = false
		timer_started[wr_bot_id] = false
		g_bot_enable = 0;
		g_bot_frame = 0;
		wr_bot_id = 0;
		destroy_bot_icon()
	}
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Icon Bot ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

public create_bot_icon(id)
{
	g_Bot_Icon_ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))

		if(file_exists(url_sprite))
			engfunc(EngFunc_SetModel, g_Bot_Icon_ent, url_sprite)
		else if(file_exists(url_sprite_xz))
			engfunc(EngFunc_SetModel, g_Bot_Icon_ent, url_sprite_xz)
		else
			return

	set_pev(g_Bot_Icon_ent, pev_solid, SOLID_NOT)
	set_pev(g_Bot_Icon_ent, pev_movetype, MOVETYPE_FLYMISSILE)
	set_pev(g_Bot_Icon_ent, pev_iuser2, id)
	set_pev(g_Bot_Icon_ent, pev_scale, 0.25)
}

destroy_bot_icon()
{
	if(g_Bot_Icon_ent)
		engfunc(EngFunc_RemoveEntity, g_Bot_Icon_ent)

	g_Bot_Icon_ent = 0
}

public addToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if(wr_bot_id == host)
	{
		return FMRES_IGNORED;
	}

	if(wr_bot_id)
	{
		if(pev_valid(ent) && (pev(ent, pev_iuser1) == pev(ent, pev_owner)))
		{
			new user = pev(ent, pev_iuser2)
			new specmode = pev(host, pev_iuser1)

			if(is_user_alive(user))
			{
				new Float: playerOrigin[3]
				pev(user, pev_origin, playerOrigin)
				playerOrigin[2] += 42
				engfunc(EngFunc_SetOrigin, ent, playerOrigin)

				if(specmode == 4)
				{
					set_es(es, ES_Effects, EF_NODRAW)
				}
			}
		}
	}

	return FMRES_IGNORED;
}

public BhopTouch(iBlock, id)
{
	if(GetBhopBlocks(g_bBlocks, iBlock))
		if(is_user_bot(id))
			return HAM_SUPERCEDE;

	return PLUGIN_CONTINUE;
}

SetTouch()
{
	RegisterHam(Ham_Touch, "func_door", "BhopTouch");

	new iDoor = FM_NULLENT;
	while((iDoor = find_ent_by_class( iDoor, "func_door")))
		SetBhopBlocks(g_bBlocks, iDoor);
}



//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ MySQL Method !!! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#if defined SQL
public country_flag_add()
{
	new FLAG[4]

	if (file_exists(CountryData))
	{
		new FileOpen = fopen(CountryData, "rt")
		new Text[96], szArg1[25], szArg2[3]

		while(!feof(FileOpen))
		{
			fgets(FileOpen, Text, sizeof(Text) - 1)
			trim(Text)
			replace_all(Text,64,","," ")

			strtok(Text, szArg1, charsmax(szArg1), szArg2, charsmax(szArg2), ' ')

			if(equali(szArg1, g_szMapName))
			{
				FLAG = szArg2;
			}
		}

		fclose(FileOpen)

		if (equali(FLAG, "")) FLAG = "xz";
		if (equali(FLAG, "n-")) FLAG = "xz";

		formatex(url_sprite, charsmax(url_sprite), "sprites/wrbot/%s.spr", FLAG);
		formatex(url_sprite_xz, charsmax(url_sprite_xz), "sprites/wrbot/xz.spr");
		if(file_exists(url_sprite))
			precache_model(url_sprite)
		else if(file_exists(url_sprite_xz))
			precache_model(url_sprite_xz)
		else
			return
	}
}

public SQL_Country()
{
	delete_file(CountryData)
	Local_ini = fopen(CountryData, "w");
	SQL_ThreadQuery(g_SqlTuple, "SQL_WorkHandle", "SELECT * FROM local")
}

public SQL_WorkHandle(failstate, Handle:hQuery, error[], errcode, cData[], iSize, Float:fQueueTime)
{
	if( failstate == TQUERY_CONNECT_FAILED )
	{
		set_fail_state("Could not connect to database.");
	}
	else if( failstate == TQUERY_QUERY_FAILED )
	{
		set_fail_state("Query failed.");
	}
	else if( errcode )
	{
		log_amx("Error on query: %s", error);
	}
	else
	{
		new return_flag[4], sz_map[64];

		while( SQL_MoreResults(hQuery) )
		{
			new sz_map_id = SQL_FieldNameToNum( hQuery, "map" );
			new country_id = SQL_FieldNameToNum( hQuery, "country" );

			SQL_ReadResult(hQuery, sz_map_id, sz_map, charsmax(sz_map))
			SQL_ReadResult(hQuery, country_id, return_flag, charsmax(return_flag))

			fprintf(Local_ini, "%s,%s^n", sz_map,return_flag)
			SQL_NextRow(hQuery)
		}
	}

	fclose(Local_ini);
	SQL_FreeHandle(hQuery)
}

public SQL_QUERY()
{
	new query[256]
	format(query,charsmax(query),"SELECT * FROM `%s`", g_szMapName)
	SQL_ThreadQuery(g_SqlTuple, "SQL_OWN_QUERY", query)
}

public SQL_OWN_QUERY(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime)
{
	if( iFailState != TQUERY_SUCCESS )
	{
		return log_amx("WR BOT ERROR: #%d - %s", iErrnum, szError)
	}

	if (SQL_NumResults(hQuery))
	{
		new stolb_1 = SQL_FieldNameToNum(hQuery, "angle1")
		new stolb_2 = SQL_FieldNameToNum(hQuery, "angle2")
		new stolb_3 = SQL_FieldNameToNum(hQuery, "origin1")
		new stolb_4 = SQL_FieldNameToNum(hQuery, "origin2")
		new stolb_5 = SQL_FieldNameToNum(hQuery, "origin3")
		new stolb_6 = SQL_FieldNameToNum(hQuery, "velocity1")
		new stolb_7 = SQL_FieldNameToNum(hQuery, "velocity2")
		new stolb_8 = SQL_FieldNameToNum(hQuery, "velocity3")
		new stolb_9 = SQL_FieldNameToNum(hQuery, "button")

		new line, Float:WR_TIME_FLOAT, WR_FLAG[4];
		new Float:Angles[3], Float:Origin[3], Float:velocity[3], Keys;

		while( SQL_MoreResults(hQuery) )
		{
			if (!line) {
				SQL_ReadResult(hQuery, stolb_1, WR_TIME_FLOAT)
				line++;
				SQL_NextRow(hQuery)
				continue;
			}

			if (line == 1) {
				SQL_ReadResult(hQuery, stolb_1, WR_NAME, charsmax(WR_NAME))
				line++;
				SQL_NextRow(hQuery)
				continue;
			}
			if (line == 2) {
				SQL_ReadResult(hQuery, stolb_1, WR_FLAG, charsmax(WR_FLAG))
				line++;
				SQL_NextRow(hQuery)
				continue;
			}

			if (line > 2)
			{
				SQL_ReadResult(hQuery, stolb_1, Angles[0])
				SQL_ReadResult(hQuery, stolb_2, Angles[1])
				SQL_ReadResult(hQuery, stolb_3, Origin[0])
				SQL_ReadResult(hQuery, stolb_4, Origin[1])
				SQL_ReadResult(hQuery, stolb_5, Origin[2])
				SQL_ReadResult(hQuery, stolb_6, velocity[0])
				SQL_ReadResult(hQuery, stolb_7, velocity[1])
				SQL_ReadResult(hQuery, stolb_8, velocity[2])
				Keys = SQL_ReadResult(hQuery, stolb_9)

				ArrayPushArray( fPlayerAngle, Angles );
				ArrayPushArray( fPlayerOrigin, Origin );
				ArrayPushArray( fPlayerVelo, velocity );
				ArrayPushCell( fPlayerKeys, Keys );

				line++
				SQL_NextRow(hQuery)
			}
		}

		StringTimer(WR_TIME_FLOAT, WR_TIME, charsmax(WR_TIME));

		#if defined DEV_DEBUG
			server_print("Finished loading demo in %f sec.", get_gametime()-flStartTime);
		#endif
	}
	SQL_FreeHandle(hQuery)

	#if defined PUB
		set_task(2.0, "StartCountDown")
	#endif

	#if defined LAN
		plugin_activated = true;
	#endif

	return PLUGIN_HANDLED
}
#endif

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ nVault Method !!! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#if defined nVault

enum _:Consts
{
	HEADER_SIZE         = 544,
	HEADER_SIGNATURE_CHECK_SIZE = 6,
	HEADER_SIGNATURE_SIZE       = 8,
	HEADER_MAPNAME_SIZE     = 260,
	HEADER_GAMEDIR_SIZE     = 260,

	MIN_DIR_ENTRY_COUNT     = 1,
	MAX_DIR_ENTRY_COUNT     = 1024,
	DIR_ENTRY_SIZE          = 92,
	DIR_ENTRY_DESCRIPTION_SIZE  = 64,

	MIN_FRAME_SIZE          = 12,
	FRAME_CONSOLE_COMMAND_SIZE  = 64,
	FRAME_CLIENT_DATA_SIZE      = 32,
	FRAME_EVENT_SIZE        = 84,
	FRAME_WEAPON_ANIM_SIZE      = 8,
	FRAME_SOUND_SIZE_1      = 8,
	FRAME_SOUND_SIZE_2      = 16,
	FRAME_DEMO_BUFFER_SIZE      = 4,
	FRAME_NETMSG_SIZE       = 468,
	FRAME_NETMSG_DEMOINFO_SIZE  = 436,
	FRAME_NETMSG_MOVEVARS_SIZE  = 32,
	FRAME_NETMSG_MIN_MESSAGE_LENGTH = 0,
	FRAME_NETMSG_MAX_MESSAGE_LENGTH = 65536
};

enum DemoHeader {
	netProtocol,
	demoProtocol,
	mapName[HEADER_MAPNAME_SIZE],
	gameDir[HEADER_GAMEDIR_SIZE],
	mapCRC,
	directoryOffset
};

enum DemoEntry {
	dirEntryCount,
	type,
	description[DIR_ENTRY_DESCRIPTION_SIZE],
	flags,
	CDTrack,
	trackTime,
	frameCount,
	offset,
	fileLength,
	frames,
	ubuttons /* INT 16 */
};

enum FrameHeader
{
	Type,
	Float:Timestamp,
	Number
}


enum NetMsgFrame {
	Float:timestamp,
	Float:view[3],
	viewmodel
}

new iDemoEntry[DemoEntry];
new iDemoHeader[DemoHeader];
new iDemoFrame[FrameHeader];

public announce()
{
	new datadir[128];
	new filename[128];
	get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
	format( filename, charsmax( datadir ), "%s/list_xj.txt", datadir );
	delete_file(filename);
	iXJWRs = fopen(filename, "wb");
	new CURL:curl = curl_easy_init();
	if(curl)
	{
		curl_easy_setopt(curl, CURLOPT_URL, "http://xtreme-jumps.eu/demos.txt");
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write_xj");
		curl_easy_perform(curl, "complite_xj")
	}
}

public write_xj(data[], size, nmemb) {
	new real_size = size*nmemb

	for(new i = 0; i < nmemb; i++)
	{
		if(i < nmemb)
		fwrite(iXJWRs, data[i], BLOCK_BYTE);
	}

	return real_size

}

public complite_xj(CURLcode:code, CURL:curl) {
	curl_easy_cleanup(curl)
	fclose(iXJWRs);

	new datadir[128];
	new filename[128];
	get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
	format( filename, charsmax( datadir ), "%s/list_cc.txt", datadir );
	delete_file(filename);
	iCCWRs = fopen(filename, "wb");
	new CURL:curl = curl_easy_init();
	if(curl)
	{
		curl_easy_setopt(curl, CURLOPT_URL, "https://cosy-climbing.net/demoz.txt");
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write_cc");
		curl_easy_perform(curl, "complite_cc")
	}
}

public write_cc(data[], size, nmemb) {
	new real_size = size*nmemb

	for(new i = 0; i < nmemb; i++)
	{
		if(i < nmemb)
		fwrite(iCCWRs, data[i], BLOCK_BYTE);
	}

	return real_size

}

public complite_cc(CURLcode:code, CURL:curl) {
	curl_easy_cleanup(curl)
	fclose(iCCWRs);

	OnDemosComplete(0);
}

public OnDemosComplete( Index )
{
		new demoslist[128];
		get_localinfo( "amxx_datadir", demoslist, charsmax( demoslist ) );
		format( demoslist, charsmax( demoslist ), "%s/list_xj.txt", demoslist );
		#if defined DEV_DEBUG
		server_print( "Parsing XJ Demo List" );
		#endif
		new iDemosList  = fopen( demoslist, "rb" );
		new ExplodedString[7][128];
		new Line[128];
		new MapName[64];
		get_mapname( MapName, 63 );
		format( MapName, charsmax( MapName ), "%s ", MapName );
		while ( !feof( iDemosList ) )
		{
			fgets( iDemosList, Line, charsmax( Line ) );
			ExplodeString( ExplodedString, 6, 127, Line, ' ' );
			new parsedmap[128];
			parsedmap = ExplodedString[0];
			format( parsedmap, charsmax( parsedmap ), "%s ", parsedmap );
			if ( containi( parsedmap, MapName ) > -1 )
			{
				bFoundDemo = true;
				break;
			}
		}
		if ( !bFoundDemo )
		{
			get_mapname( MapName, 63 );
			format( MapName, charsmax( MapName ), "%s[", MapName );
			fseek( iDemosList, 0, SEEK_SET );
			while ( !feof( iDemosList ) )
			{
				fgets( iDemosList, Line, charsmax( Line ) );
				ExplodeString( ExplodedString, 6, 127, Line, ' ' );
				if ( containi( ExplodedString[0], MapName ) > -1 )
				{
					bFoundDemo = true;
					break;
				}
			}
		}
		else
		{
			new Float:Date = str_to_float( ExplodedString[1] );
			new sWRTime[24];
			fnConvertTime( Date, sWRTime, charsmax( sWRTime ) );
			format( iArchiveName, charsmax( iArchiveName ), "%s_%s_%s", ExplodedString[0], ExplodedString[2], sWRTime );
			StringTimer(Date, WR_TIME, sizeof(WR_TIME) - 1);
			WR_NAME = ExplodedString[2];
			new iLink[512];
			format( iLink, charsmax( iLink ), "http://files.xtreme-jumps.eu/demos/%s.rar", iArchiveName );
			new datadir[128];
			get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
			format( datadir, charsmax( datadir ), "%s/%s.rar", datadir, iArchiveName );
			DownloadDemoArchive(iArchiveName, iLink);
		}

		if(!bFoundDemo)
		{
			CheckCCList();
		}
}

public CheckCCList()
{
	new demoslist[128];
	get_localinfo( "amxx_datadir", demoslist, charsmax( demoslist ) );
	format( demoslist, charsmax( demoslist ), "%s/list_cc.txt", demoslist );
	#if defined DEV_DEBUG
	server_print( "Parsing Cosy Demo List" );
	#endif
	new iDemosList  = fopen( demoslist, "rb" );
	new ExplodedString[7][128];
	new Line[128];
	new MapName[64];
	get_mapname( MapName, 63 );
	format( MapName, charsmax( MapName ), "%s ", MapName );
	while ( !feof( iDemosList ) )
	{
		fgets( iDemosList, Line, charsmax( Line ) );
		ExplodeString( ExplodedString, 6, 127, Line, ' ' );
		new parsedmap[128];
		parsedmap = ExplodedString[0];
		format( parsedmap, charsmax( parsedmap ), "%s ", parsedmap );
		if ( containi( parsedmap, MapName ) > -1 )
		{
			bFoundDemo = true;
			break;
		}
	}
	if ( !bFoundDemo )
	{
		get_mapname( MapName, 63 );
		format( MapName, charsmax( MapName ), "%s[", MapName );
		fseek( iDemosList, 0, SEEK_SET );
		while ( !feof( iDemosList ) )
		{
			fgets( iDemosList, Line, charsmax( Line ) );
			ExplodeString( ExplodedString, 6, 127, Line, ' ' );
			if ( containi( ExplodedString[0], MapName ) > -1 )
			{
				bFoundDemo = true;
				break;
			}
		}
	}else  {
		new Float:Date = str_to_float( ExplodedString[1] );
		new sWRTime[24];
		fnConvertTime( Date, sWRTime, charsmax( sWRTime ) );
		format( iArchiveName, charsmax( iArchiveName ), "%s_%s_%s", ExplodedString[0], ExplodedString[2], sWRTime );
		StringTimer(Date, WR_TIME, sizeof(WR_TIME) - 1);
		WR_NAME = ExplodedString[2];
		new iLink[512];
		format( iLink, charsmax( iLink ), "https://cosy-climbing.net/files/demos/%s.rar", iArchiveName );
		new datadir[128];
		get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
		format( datadir, charsmax( datadir ), "%s/%s.rar", datadir, iArchiveName );
		DownloadDemoArchive(iArchiveName, iLink);
	}
}



public DownloadDemoArchive(iArchiveName[], iLink[])
{
	new datadir[128];
	new filename[128];
	get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
	format( filename, charsmax( datadir ), "%s/%s.rar",datadir, iArchiveName );
	//delete_file(filename);
	iArchive = fopen(filename, "wb");
	new CURL:curl = curl_easy_init();
	//server_print("%s iLink", iLink);
	if(curl)
	{
		curl_easy_setopt(curl, CURLOPT_URL, iLink);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write_archive");
		curl_easy_perform(curl, "complite_archive")
	}
}

public write_archive(data[], size, nmemb) {
	new real_size = size*nmemb

	for(new i = 0; i < nmemb; i++)
	{
		if(i < nmemb)
		fwrite(iArchive, data[i], BLOCK_BYTE);
	}

	return real_size

}

public complite_archive(CURLcode:code, CURL:curl) {
	curl_easy_cleanup(curl)
	fclose(iArchive);

	OnArchiveComplete();
}


public OnArchiveComplete()
{
	new RARArchive[128];

	format( RARArchive, charsmax( RARArchive ), "%s.rar", iArchiveName );
	AA_Unarchive(RARArchive);
	new datadir[128];
	get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
	format( datadir, charsmax( datadir ), "%s/%s.rar", datadir, iArchiveName );
	delete_file( datadir );

	new szNavName[256];

	get_localinfo( "amxx_datadir", datadir, charsmax( datadir ) );
	format( szNavName, sizeof(szNavName), "%s", datadir, iArchiveName );
	if(!dir_exists(szNavName))
	{
		mkdir(szNavName);
	}
	format( iNavName, sizeof(iNavName), "%s/%s.nav", datadir, iArchiveName );
	format( iDemoName, sizeof(iDemoName), "%s/%s.dem", datadir, iArchiveName );
	if ( !file_exists( iNavName ) )
	{
		iFile = fopen( iDemoName, "rb" );
		if ( iFile )
		{
			iParsedFile = fopen( iNavName, "w" );
			ReadHeaderX();
			/*fclose(iFile);
			fclose(iParsedFile);
			LoadParsedInfo( szNavName );*/
		}
	}else  {
		LoadParsedInfo( iNavName );
	}

	#if defined DEV_DEBUG
	flStartTime = get_gametime();
	#endif
}


public fnConvertTime( Float:time, convert_time[], len )
{
	new sTemp[24];
	new Float:fSeconds = time, iMinutes;

	iMinutes        = floatround( fSeconds / 60.0, floatround_floor );
	fSeconds        -= iMinutes * 60.0;
	new intpart     = floatround( fSeconds, floatround_floor );
	new Float:decpart   = (fSeconds - intpart) * 100.0;
	intpart         = floatround( decpart );

	formatex( sTemp, charsmax( sTemp ), "%02i%02.0f.%02d", iMinutes, fSeconds, intpart );


	formatex( convert_time, len, sTemp );
	#if defined DEV_DEBUG
	server_print( "%f %s, %s",time, sTemp, convert_time);
	#endif
	return(PLUGIN_HANDLED);
}

public LoadParsedInfo(szNavName[])
{
	iFile = fopen( szNavName, "rb" );
	new Ent = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
	set_pev(Ent, pev_classname, "NavThink");
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01 );
}

public ReadHeaderX()
{
	if ( IsValidDemoFile( iFile ) )
	{
		ReadHeader( iFile );
		new Ent = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
		set_pev(Ent, pev_classname, "DemThink");
		set_pev(Ent, pev_nextthink, get_gametime() + 0.01 );

	}else {
		server_print( "NOTVALID" );
	}
}

public bool:IsValidDemoFile( file )
{
	fseek( file, 0, SEEK_END );
	iDemo_header_size = ftell( file );


	if ( iDemo_header_size < HEADER_SIZE )
	{
		return(false);
	}

	fseek( file, 0, SEEK_SET );
	new signature[HEADER_SIGNATURE_CHECK_SIZE];


	fread_blocks( file, signature, sizeof(signature), BLOCK_CHAR );

	if ( !contain( "HLDEMO", signature ) )
	{
		return(false);
	}

	return(true);
}


public ReadHeader( file )
{
	fseek( file, HEADER_SIGNATURE_SIZE, SEEK_SET );

	fread( file, iDemoHeader[demoProtocol], BLOCK_INT );

	if ( iDemoHeader[demoProtocol] != 5 )
	{
	}

	fread( file, iDemoHeader[netProtocol], BLOCK_INT );

	if ( iDemoHeader[netProtocol] != 48 )
	{
	}

	fread_blocks( file, iDemoHeader[mapName], HEADER_MAPNAME_SIZE, BLOCK_CHAR );
	fread_blocks( file, iDemoHeader[gameDir], HEADER_GAMEDIR_SIZE, BLOCK_CHAR );

	fread( file, iDemoHeader[mapCRC], BLOCK_INT );
	fread( file, iDemoHeader[directoryOffset], BLOCK_INT );

	fseek( file, iDemoHeader[directoryOffset], SEEK_SET );

	new newPosition = ftell( file );

	if ( newPosition != iDemoHeader[directoryOffset] )
	{
		/*server_print( "kek :(" );*/
	}
	fread( file, iDemoEntry[dirEntryCount], BLOCK_INT );
	for ( new i = 0; i < iDemoEntry[dirEntryCount]; i++ )
	{
		fread( file, iDemoEntry[type], BLOCK_INT );
		fread_blocks( file, iDemoEntry[description], DIR_ENTRY_DESCRIPTION_SIZE, BLOCK_CHAR );
		fread( file, iDemoEntry[flags], BLOCK_INT );
		fread( file, iDemoEntry[CDTrack], BLOCK_INT );
		fread( file, iDemoEntry[trackTime], BLOCK_INT );
		fread( file, iDemoEntry[frameCount], BLOCK_INT );
		fread( file, iDemoEntry[offset], BLOCK_INT );
		fread( file, iDemoEntry[fileLength], BLOCK_INT );
	}

	fseek( file, iDemoEntry[offset], SEEK_SET );

/* server_print( "%d %d %s %s %d %d %d", iDemoHeader[demoProtocol], iDemoHeader[netProtocol], iDemoHeader[mapName], iDemoHeader[gameDir], iDemoHeader[mapCRC], iDemoHeader[directoryOffset], iDemoEntry[dirEntryCount] ); */
}

public ReadParsed( iEnt )
{
	if ( iFile )
	{
		new szLineData[512];
		static sExplodedLine[11][150];
		if ( !feof( iFile ) )
		{
			fseek(iFile, 0, SEEK_CUR);
			new iSeek = ftell(iFile);
			fseek(iFile, 0, SEEK_END);
			#if defined DEV_DEBUG
			new iFinish = ftell(iFile);
			server_print("%.2f%% NAV READED", float(iSeek)/float(iFinish)*100.0);
			#endif
			fseek(iFile, iSeek, SEEK_SET);

			/* read one line */
			fgets( iFile, szLineData, charsmax( szLineData ) );


			/*
			 * replace newlines with a null character to prevent headaches
			 * replace(szLineData, charsmax(szLineData), "^n", "")
			 */

			ExplodeString( sExplodedLine, 10, 50, szLineData, '|' );
			if ( equal( sExplodedLine[1], "ASD" ) )
			{
				new Keys        = str_to_num( sExplodedLine[2] );
				new Float:Angles[3];
				Angles[0]   = str_to_float( sExplodedLine[3] );
				Angles[1]   = str_to_float( sExplodedLine[4] );
				Angles[2]   = 0.0;
				new Float:Origin[3];
				Origin[0]   = str_to_float( sExplodedLine[5] );
				Origin[1]   = str_to_float( sExplodedLine[6] );
				Origin[2]   = str_to_float( sExplodedLine[7] );
				new Float:velocity[3]
				velocity[0] = str_to_float( sExplodedLine[8] );
				velocity[1] = str_to_float( sExplodedLine[9] );
				velocity[2] = 0.0;

			ArrayPushArray( fPlayerAngle, Angles );
			ArrayPushArray( fPlayerOrigin, Origin );
				ArrayPushArray( fPlayerVelo, velocity );
				ArrayPushCell( fPlayerKeys, Keys );
			}
			set_pev( iEnt, pev_nextthink, get_gametime()+0.0001 );
			return true;
		}
		else
		{
			#if defined DEV_DEBUG
			server_print("Finished loading demo in %f sec.", get_gametime()-flStartTime);
			#endif
			return false;
		}
	}

	return false;
}
public ReadFrames( file )
{

	fseek(file, 0, SEEK_CUR);
	new iSeek = ftell(file);
	fseek(file, 0, SEEK_END);
	fseek(iFile, iSeek, SEEK_SET);
	#if defined DEV_DEBUG
	new iFinish = ftell(file);
	server_print("%.2f%% DEMO PARSED", float(iSeek)/float(iFinish)*100.0);
	#endif

	static sum;

	if ( !feof( file ) )
	{
		new FrameType = ReadFrameHeader( file );
		new breakme;
		/*
		 * server_print( "TOTAL: %d", FrameType );
		 * server_print( "LEL%d %d %d", FrameType, iDemoFrame[Timestamp], iDemoFrame[Number] );
		 */
		switch ( FrameType )
		{
			case 0:
			{
			}
			case 1:
			{
				new Float:Origin[3], Float:ViewAngles[3], Float:velocity[3], iAsd[1024];
				fseek( file, 4, SEEK_CUR );                             // read_object(demo, f.DemoInfo.timestamp);
				for ( new i = 0; i < 3; ++i )
					fseek( file, 4, SEEK_CUR );                     // read_object(demo, f.DemoInfo.RefParams.vieworg);
				for ( new i = 0; i < 3; ++i )
					fread( file, _:ViewAngles[i], BLOCK_INT );  // read_object(demo, f.DemoInfo.RefParams.viewangles);

				fseek( file, 64, SEEK_CUR );                            // пропуск до следующего участка.

				for ( new i = 0; i < 3; ++i )
					fread( file, _:velocity[i], BLOCK_INT );        // read_object(demo, f.DemoInfo.RefParams.simvel);
				for ( new i = 0; i < 3; ++i )
					fread( file, _:Origin[i], BLOCK_INT );          // read_object(demo, f.DemoInfo.RefParams.simorg);

				fseek( file, 124, SEEK_CUR );                       // пропуск до следующего участка.

				for ( new i = 0; i < 3; ++i )
					fseek( file, 4, SEEK_CUR );                     // read_object(demo, f.DemoInfo.UserCmd.viewangles);

				fseek( file, 4, SEEK_CUR );                     /* read_object(demo, f.ForwardMove); */
				fseek( file, 4, SEEK_CUR );                     /* read_object(demo, f.SideMove); */
				fseek( file, 4, SEEK_CUR );                     /* read_object(demo, f.UpmoveMove); */
				fseek( file, 2, SEEK_CUR );                     /* read_object(demo, f.lightlevel && f.align_2; */
				fread( file, iDemoEntry[ubuttons], BLOCK_SHORT );

				format( iAsd, charsmax( iAsd ), "%d|ASD|%d|%.4f|%.4f|%.3f|%.3f|%f|%.3f|%.3f|%.3f^n",sum, iDemoEntry[ubuttons], ViewAngles[0], ViewAngles[1], Origin[0],Origin[1],Origin[2], velocity[0], velocity[1], velocity[2] );
				fputs( iParsedFile, iAsd );
				fseek( file, 196, SEEK_CUR ); // static
				new length;
				fread( file, length, BLOCK_INT ); // static
				fseek( file, length, SEEK_CUR ); // static
			}
			case 2:
			{
			}
			case 3:
			{
				new ConsoleCmd[FRAME_CONSOLE_COMMAND_SIZE];
				fread_blocks( file, ConsoleCmd, FRAME_CONSOLE_COMMAND_SIZE, BLOCK_CHAR );
			}
			case 4:
			{
				sum++;
				for ( new i = 0; i < 3; ++i )                               // Бот чуть выше земли и pre будет показывать, как UP
					fseek( file, 4, SEEK_CUR );                             // write_object(o, f->origin[i]);
				for ( new i = 0; i < 3; ++i )                               // write_object(o, f->viewangles[i]);
					fseek( file, 4, SEEK_CUR );

				fseek( file, 4, SEEK_CUR );                             // write_object(o, f->weaponBits);
				fseek( file, 4, SEEK_CUR );                             // write_object(o, f->fov);
			}
			case 5:
			{
				breakme = 2;
			}
			case 6:
			{
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.flags); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.index); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.delay); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.flags); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.entityIndex); */
				for ( new i = 0; i < 3; ++i )
					fseek( file, 4, SEEK_CUR );     /* read_object(demo, f.EventArgs.origin[i]); */
				for ( new i = 0; i < 3; ++i )
					fseek( file, 4, SEEK_CUR );     /* read_object(demo, f.EventArgs.angles[i]); */
				for ( new i = 0; i < 3; ++i )
					fseek( file, 4, SEEK_CUR );     /* read_object(demo, f.EventArgs.velocity[i]); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.ducking); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.fparam1); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.fparam2); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.iparam1); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.iparam2); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.bparam1); */
				fseek( file, 4, SEEK_CUR );             /* read_object(demo, f.EventArgs.bparam2); */
			}
			case 7:
			{
				fseek( file, 8, SEEK_CUR );
			}
			case 8:
			{
				fseek( file, 4, SEEK_CUR );
				new length;
				fread( file, length, BLOCK_INT );
				new msg[128];
				fread_blocks( file, msg, length, BLOCK_CHAR );
				fseek( file, 16, SEEK_CUR );
			}
			case 9:
			{
				new length = 0;
				fread( file, length, BLOCK_INT );
				new buffer[4];
				fread_blocks( file, buffer, length, BLOCK_BYTE );
			}
			default:
			{
				breakme = 2;
			}
		}

		if(breakme == 2)
		{
			return true;
		}
	}

	return false;
}


public ReadFrameHeader( file )
{
	fread( file, iDemoFrame[Type], BLOCK_BYTE );
	fread( file, _:iDemoFrame[Timestamp], BLOCK_INT );
	fread( file, iDemoFrame[Number], BLOCK_INT );

	return(iDemoFrame[Type]);
}

public ExplodeString( p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter )
{
	new nIdx    = 0, l = strlen( p_szInput );
	new nLen    = (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter ) );
	while ( (nLen < l) && (++nIdx < p_nMax) )
		nLen += (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter ) );
	return(nIdx);
}

public check_dir()
{
	new demoslist[32], file[64];
	get_localinfo( "amxx_datadir", demoslist, charsmax( demoslist ) );
	new dirh = open_dir(demoslist, file, 63) // открывает дерикторию
	// Цикл с переборкой файлов
	while(next_file(dirh, file, 63))
	{
		new left[128], right[128], g_right[32], g_left[32], texturl[128]
		strtok(file, left, 127, right, 127, '.') // Уберает из названия карты, символы после <" . ">
		strtok(right, g_left, 31, g_right, 31, '.') // Повторно убираем <" . "> т.к. в демке 2 точки
		formatex(texturl, charsmax(texturl), "%s/%s", demoslist, file) // url для удаления файлов

		if(equali(g_right, "dem") || equali(g_right, "nav") || equali(g_right, "rar") || equali(g_right, "zip")) // Условия сравнения файла на наличие bsp
		{
			delete_file(texturl)
		}
	}
}

public parsing_country(data[])
{
	new demoslist[128];
	get_localinfo( "amxx_datadir", demoslist, charsmax( demoslist ) );
	if(equali(data, "xj"))
		format( demoslist, charsmax( demoslist ), "%s/list_xj.txt", demoslist );
	else if(equali(data, "cc"))
		format( demoslist, charsmax( demoslist ), "%s/list_cc.txt", demoslist );

	#if defined DEV_DEBUG
	server_print( "Parsing XJ Demo List" );
	#endif
	new iDemosList  = fopen( demoslist, "rb" );
	new ExplodedString[7][128];
	new Line[128];
	new MapName[64];
	get_mapname( MapName, 63 );
	format( MapName, charsmax( MapName ), "%s ", MapName );
	while ( !feof( iDemosList ) )
	{
		fgets( iDemosList, Line, charsmax( Line ) );
		ExplodeString( ExplodedString, 6, 127, Line, ' ' );
		new parsedmap[128];
		parsedmap = ExplodedString[0];
		format( parsedmap, charsmax( parsedmap ), "%s ", parsedmap );
		if ( containi( parsedmap, MapName ) > -1 )
		{
			g_Demos = true;
			break;
		}
	}
	if ( !g_Demos )
	{
		get_mapname( MapName, 63 );
		format( MapName, charsmax( MapName ), "%s[", MapName );
		fseek( iDemosList, 0, SEEK_SET );
		while ( !feof( iDemosList ) )
		{
			fgets( iDemosList, Line, charsmax( Line ) );
			ExplodeString( ExplodedString, 6, 127, Line, ' ' );
			if ( containi( ExplodedString[0], MapName ) > -1 )
			{
				g_Demos = true;
				break;
			}
		}
	}
	else
	{
		new FLAG[10]
		formatex(FLAG, charsmax(FLAG), "%s", ExplodedString[3]);
		trim(FLAG)
		if (equali(FLAG, "")) FLAG = "xz";
		if (equali(FLAG, "n-")) FLAG = "xz";

		formatex(url_sprite, charsmax(url_sprite), "sprites/wrbot/%s.spr", FLAG);
		formatex(url_sprite_xz, charsmax(url_sprite_xz), "sprites/wrbot/xz.spr");
		if(file_exists(url_sprite))
			precache_model(url_sprite)
		else if(file_exists(url_sprite_xz))
			precache_model(url_sprite_xz)
		else
			return
	}

	if ( !g_Demos && equali(data, "xj") )
		parsing_country("cc")
}
#endif


//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Lan Version !!! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#if defined LAN
public StartWatchWR(id)
{
	if (license)
	{
		if(plugin_activated)
		{
			StartCountDown();
			client_cmd(0, "spk fvox/activated")

			if(!is_user_bot(id) && is_user_localhost(id) && cs_get_user_team(id) != CS_TEAM_SPECTATOR)
			{
				set_task(0.5, "ct", id);
			}
		}
		else
		{
			ColorChat(id, RED,  "^4[WR-BOT]^1 Please wait a moment, plugin receives data.")
		}
	}
	else
	{
		if(b_CvarError)
			ColorChat(id, RED,  "^4[WR-BOT ^3v%s^1]^1 ERROR ... Switch the setting to -> ^3sv_lan 0 ^1", VERSION);
		else
			ColorChat(id, RED, "^4[WR-BOT ^3v%s^1]^1 You did not buy a license for the plugin, or have not confirmed your profile.", VERSION);
	}
}

public plugin_info(id)
{
	if(plugin_activated && license && is_user_connected(id))
	{
		remove_task(id)
		client_cmd(0, "spk fvox/blip")
		set_hudmessage(159, 165, 255, 0.05, 0.3, 2, 0.1, 7.0, 0.03)
		show_hudmessage(id, "Loading DEMO completed^nYou can see the WR right now /playwr^n")
		ColorChat(id, RED,  "^4[WR-BOT ^3v%s^1]^1 All the information you can see on the site ^3KREEDZ.RU ^1", VERSION)
	}
}

public Stop(id)
{
	if (license)
	{
		server_cmd("kick #%d", get_user_userid(wr_bot_id))
		ct(id)
		client_cmd(0, "spk fvox/deactivated")
	}
}

public ct(id)
{
	new CsTeams:team = cs_get_user_team(id)
	if (team == CS_TEAM_CT || team == CS_TEAM_T)
	{
		cs_set_user_team(id,CS_TEAM_SPECTATOR)
		set_pev(id, pev_solid, SOLID_NOT)
		set_pev(id, pev_movetype, MOVETYPE_FLY)
		set_pev(id, pev_effects, EF_NODRAW)
		set_pev(id, pev_deadflag, DEAD_DEAD)
		client_cmd(id, ";specmode 4") //first person
		static name[32]
		get_user_name(wr_bot_id, name,31)
		client_cmd(id, "follow ^"%s^"",name)
	}
	else
	{
		cs_set_user_team(id,CS_TEAM_CT)
		set_pev(id, pev_effects, 0)
		set_pev(id, pev_movetype, MOVETYPE_WALK)
		set_pev(id, pev_deadflag, DEAD_NO)
		set_pev(id, pev_takedamage, DAMAGE_AIM)
		CmdRespawn(id)
		// Возвращение оружия в спеках
		//strip_user_weapons(id)
		ham_give_weapon(id,"weapon_knife")
		ham_give_weapon(id,"weapon_usp")
	}
	return PLUGIN_HANDLED
}

public Ham_PlayerSpawn_P(id)
{
	if(is_user_localhost(id) && is_user_alive(id) && !is_user_bot(id) && firstspawn[id])
	{
		new steamid[32]
		get_user_authid(id, steamid, charsmax(steamid))

		firstspawn[id] = false;
		SQL_Check_license(steamid)
		set_task(0.5, "plugin_info", id,_,_,"b")
	}

	if(is_user_alive(id) && is_user_bot(id))
	{
		ham_give_weapon(id,"weapon_knife")
		ham_give_weapon(id,"weapon_usp")
	}
}

public CmdRespawn(id)
{
	if ( get_user_team(id) == 3 )
		return PLUGIN_HANDLED
	else
		ExecuteHamB(Ham_CS_RoundRespawn, id)

	return PLUGIN_HANDLED
}
#endif

public client_connect(id)
{
	if(is_user_bot(id)) return
	#if defined LAN
		new bool:LANus = true;
	#else
		new bool:LANus = false;
	#endif

	if(LANus || equali(gl_verification, "STEAM"))
	{
		firstspawn[id] = true
		b_CvarError = false
		set_task(2.0, "Client_Cvars", id);
	}
}

public Client_Cvars(id)
{
	query_client_cvar(id, "sv_lan" ,"Check_Cvars");
}

public Check_Cvars(id, const szVar[], const szValue[])
{
	if((equali(szVar, "sv_lan") && str_to_num(szValue) != 0))
	{
		ColorChat(id, RED,  "^4[WR-BOT ^3v%s^1]^1 ERROR ... Switch the setting to -> ^3sv_lan 0 ^1", VERSION);
		b_CvarError = true;
	}
}

stock is_user_localhost(id)
{
	new szIP[16];
	get_user_ip(id, szIP, sizeof(szIP) - 1, 1);

	if(equal(szIP, "loopback") || equal(szIP, "127.0.0.1"))
	{
		return true;
	}
	return false;
}

stock ham_give_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7))
		return 0

	new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon));

	if(!pev_valid(wEnt))
		return 0

	set_pev(wEnt,pev_spawnflags,SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn,wEnt)

	if(!ExecuteHamB(Ham_AddPlayerItem,id,wEnt))
	{
		if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) | FL_KILLME);
		return 0
	}

	ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,id)
	return 1
}

stock StringTimer(const Float:flRealTime, szOutPut[], const iSizeOutPut)
{
	static Float:flTime, iMinutes, iSeconds, iMiliSeconds, Float:iMili;
	new string[12]

	flTime = flRealTime;

	if(flTime < 0.0) flTime = 0.0;

	iMinutes = floatround(flTime / 60, floatround_floor);
	iSeconds = floatround(flTime - (iMinutes * 60), floatround_floor);
	iMili = floatfract(flRealTime)
	formatex(string, 11, "%.02f", iMili >= 0 ? iMili + 0.005 : iMili - 0.005);
	iMiliSeconds = floatround(str_to_float(string) * 100, floatround_floor);

	formatex(szOutPut, iSizeOutPut, "%02d:%02d.%02d", iMinutes, iSeconds, iMiliSeconds);
}
