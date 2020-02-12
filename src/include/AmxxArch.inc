/*
  *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * See LICENSE.TXT file for more information.
 *
 */
 #if defined _AmxxArch_included
	#endinput
#endif
#define _AmxxArch_included
 
 
#if AMXX_VERSION_NUM >= 175
	#pragma reqlib AmxxArch
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib AmxxArch
	#endif
#else
	#pragma library AmxxArch
#endif


native AA_Unarchive( const filename[], const destfile[] );



/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11274\\ f0\\ fs16 \n\\ par }
*/
