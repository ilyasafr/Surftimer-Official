// Start Timer
public void CL_OnStartTimerPress(int client)
{
	if (!IsFakeClient(client))
	{
		if (IsValidClient(client))
		{
			if (!g_bServerDataLoaded)
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					CPrintToChat(client, "%t", "BPress1", g_szChatPrefix);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
			else if (g_bLoadingSettings[client])
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					CPrintToChat(client, "%t", "BPress2", g_szChatPrefix);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
			else if (!g_bSettingsLoaded[client])
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					CPrintToChat(client, "%t", "BPress3", g_szChatPrefix);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
		}
		if (g_bNewReplay[client] || g_bNewBonus[client]) // Don't allow starting the timer, if players record is being saved
		return;
	}

	if (!g_bSpectate[client] && !g_bNoClip[client] && ((GetGameTime() - g_fLastTimeNoClipUsed[client]) > 2.0))
	{
		if (g_bActivateCheckpointsOnStart[client])
		g_bCheckpointsEnabled[client] = true;

		// Reset Run Variables
		tmpDiff[client] = 9999.0;
		g_fPauseTime[client] = 0.0;
		g_fStartPauseTime[client] = 0.0;
		g_bPause[client] = false;
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntityRenderMode(client, RENDER_NORMAL);
		g_fStartTime[client] = GetGameTime();
		g_fCurrentRunTime[client] = 0.0;
		g_bPositionRestored[client] = false;
		g_bMissedMapBest[client] = true;
		g_bMissedBonusBest[client] = true;
		g_bTimerRunning[client] = true;
		g_bTop10Time[client] = false;
		// Strafe Sync
		g_iGoodGains[client] = 0;
		g_iTotalMeasures[client] = 0;
		g_iCurrentCheckpoint[client] = 0;
		g_iCheckpointsPassed[client] = 0;
		g_bIsValidRun[client] = false;

		if (!IsFakeClient(client))
		{
			// Reset Checkpoint Times
			for (int i = 0; i < CPLIMIT; i++)
			g_fCheckpointTimesNew[g_iClientInZone[client][2]][client][i] = 0.0;

			// Set missed record time variables
			if (g_iClientInZone[client][2] == 0)
			{
				if (g_fPersonalRecord[client] > 0.0)
				g_bMissedMapBest[client] = false;
			}
			else
			{
				if (g_fPersonalRecordBonus[g_iClientInZone[client][2]][client] > 0.0)
				g_bMissedBonusBest[client] = false;

			}
		}

		if (!g_bPracticeMode[client] && !IsFakeClient(client)) {
			char szSpeed[128];
			char preMessage[128];
			Format(szSpeed, sizeof(szSpeed), "%i", RoundToNearest(g_fLastSpeed[client]));
			Format(preMessage, sizeof(preMessage), "%t", "StartPrestrafe", g_szChatPrefix, szSpeed);
			if (g_iPrespeedText[client])
				CPrintToChat(client, preMessage);
		
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i))
					continue;

 				if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
					continue;

 				int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if (ObserverMode != 4 && ObserverMode != 5)
					continue;

 				int ObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				if (ObserverTarget != client)
					continue;

				if (g_iPrespeedText[i])
					CPrintToChat(i, preMessage);
			}
		}

	}

	// Play Start Sound
	PlayButtonSound(client);

	// Start recording for record bot
	if ((!IsFakeClient(client) && GetConVarBool(g_hReplayBot)) || (!IsFakeClient(client) && GetConVarBool(g_hBonusBot)))
	{
		if (!IsPlayerAlive(client) || GetClientTeam(client) == 1)
		{
			if (g_hRecording[client] != null)
				StopRecording(client);
		}
		else
		{
			if (g_hRecording[client] != null)
				StopRecording(client);
			StartRecording(client);
			if (g_bhasStages)
				Stage_StartRecording(client);
		}
	}
}

// End Timer
public void CL_OnEndTimerPress(int client)
{
	if (!IsValidClient(client))
		return;

	// Print bot finishing message to spectators
	if (IsFakeClient(client) && g_bTimerRunning[client])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsPlayerAlive(i))
			{
				int SpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if (SpecMode == 4 || SpecMode == 5)
				{
					int Target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
					if (Target == client)
					{
						if (Target == g_RecordBot)
							CPrintToChat(i, "%t", "ReplayFinishingMsg", g_szChatPrefix, g_szReplayName, g_szReplayTime);
						if (Target == g_BonusBot)
							CPrintToChat(i, "%t", "ReplayFinishingMsgBonus", g_szChatPrefix, g_szBonusName, g_szZoneGroupName[g_iClientInZone[g_BonusBot][2]], g_szBonusTime);
					}
				}
			}
		}

		PlayButtonSound(client);

		g_bTimerRunning[client] = false;
		return;
	}

	// If timer is not on, play error sound and return
	if (!g_bTimerRunning[client])
	{
		ClientCommand(client, "play buttons\\button10.wav");
		return;
	}
	else
		PlayButtonSound(client);

	// Get client name
	char szName[128];
	GetClientName(client, szName, 128);

	// Get runtime and format it to a string
	g_fFinalTime[client] = GetGameTime() - g_fStartTime[client] - g_fPauseTime[client];
	FormatTimeFloat(client, g_fFinalTime[client], 3, g_szFinalTime[client], 32);

	/*====================================
	=        Handle Practice Mode        =
	====================================*/

	if (g_bPracticeMode[client])
	{
		if (g_iClientInZone[client][2] > 0)
			CPrintToChat(client, "%t", "BPress4", g_szChatPrefix, szName, g_szFinalTime[client]);
		else
			CPrintToChat(client, "%t", "BPress5", g_szChatPrefix, szName, g_szFinalTime[client]);
		
		/* Start function call */
		Call_StartForward(g_PracticeFinishForward);

		/* Push parameters one at a time */
		Call_PushCell(client);
		Call_PushFloat(g_fFinalTime[client]);
		Call_PushString(g_szFinalTime[client]);

		/* Finish the call, get the result */
		Call_Finish();

		return;
	}

	// Get zonegroup and style
	int zGroup = g_iClientInZone[client][2];
	int style = g_iCurrentStyle[client];

	/*====================================
	=         Handling Map Times         =
	====================================*/

	if (zGroup == 0)
	{
		if (style == 0)
		{
			// Make a new record bot?
			if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[0][0] || g_fReplayTimes[0][0] == 0.0))
			{
				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client])
				{
					g_fReplayTimes[0][0] = g_fFinalTime[client];
					g_bNewReplay[client] = true;
					CreateTimer(3.0, ReplayTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}

			char szDiff[54];
			float diff;

			// Record bools init
			g_bMapFirstRecord[client] = false;
			g_bMapPBRecord[client] = false;
			g_bMapSRVRecord[client] = false;

			g_OldMapRank[client] = g_MapRank[client];

			diff = g_fPersonalRecord[client] - g_fFinalTime[client];
			FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));
			if (diff > 0.0)
			Format(g_szTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
			else
			Format(g_szTimeDifference[client], sizeof(szDiff), "+%s", szDiff);

			// If the server already has a record
			if (g_MapTimesCount > 0)
			{
				
				g_fOldRecordMapTime = g_fRecordMapTime;
				if (g_fFinalTime[client] < g_fRecordMapTime)
				{
					// New fastest time in map
					g_bMapSRVRecord[client] = true;
					g_fRecordMapTime = g_fFinalTime[client];
					Format(g_szRecordPlayer, 128, "%s", szName);
					FormatTimeFloat(1, g_fRecordMapTime, 3, g_szRecordMapTime, 128);

					// Insert latest record
					db_InsertLatestRecords(g_szSteamID[client], szName, g_fFinalTime[client]);

					// Update Checkpoints
					if (!g_bPositionRestored[client])
					{
						for (int i = 0; i < CPLIMIT; i++)
						{
							g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
						}
						g_bCheckpointRecordFound[zGroup] = true;
					}

					if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
					{
						g_bNewReplay[client] = true;
						g_fReplayTimes[0][0] = g_fFinalTime[client];
						CreateTimer(3.0, ReplayTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
			else
			{
				// Has to be the new record, since it is the first completion
				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
				{
					g_fReplayTimes[0][0] = g_fFinalTime[client];
					g_bNewReplay[client] = true;
					CreateTimer(3.0, ReplayTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}

				g_fOldRecordMapTime = g_fRecordMapTime;
				g_bMapSRVRecord[client] = true;
				g_fRecordMapTime = g_fFinalTime[client];
				Format(g_szRecordPlayer, 128, "%s", szName);
				FormatTimeFloat(1, g_fRecordMapTime, 3, g_szRecordMapTime, 128);

				// Insert latest record
				db_InsertLatestRecords(g_szSteamID[client], szName, g_fFinalTime[client]);

				// Update Checkpoints
				if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
				{
					for (int i = 0; i < CPLIMIT; i++)
					{
						g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
					}
					g_bCheckpointRecordFound[zGroup] = true;
				}

				g_fOldRecordMapTime = g_fRecordMapTime;
			}


			// Clients first record
			if (g_fPersonalRecord[client] == 0.0)
			{
				g_fPersonalRecord[client] = g_fFinalTime[client];
				g_pr_finishedmaps[client][0]++;
				g_MapTimesCount++;
				FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

				g_bMapFirstRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);

				db_selectRecord(client);

			}
			else if (diff > 0.0)
			{
				// Client's new record
				g_fPersonalRecord[client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

				g_bMapPBRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);

				db_selectRecord(client);

			}
			if (!g_bMapSRVRecord[client] && !g_bMapFirstRecord[client] && !g_bMapPBRecord[client])
			{
				// for ck_min_rank_announce
				db_currentRunRank(client);
			}
		}
		else if (style != 0)
		{
			g_fOldRecordStyleMapTime[style] = g_fRecordStyleMapTime[style];

			// Make a new record bot?
			if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[0][style] || g_fReplayTimes[0][style] == 0.0))
			{
				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client])
				{
					g_fReplayTimes[0][style] = g_fFinalTime[client];
					g_bNewReplay[client] = true;
					Handle pack;
					CreateDataTimer(3.0, StyleReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, style);
				}
			}

			// Styles
			char szDiff[54];
			float diff;

			// Record bools init
			g_bStyleMapFirstRecord[style][client] = false;
			g_bStyleMapPBRecord[style][client] = false;
			g_bStyleMapSRVRecord[style][client] = false;

			g_OldStyleMapRank[style][client] = g_StyleMapRank[style][client];

			diff = g_fPersonalStyleRecord[style][client] - g_fFinalTime[client];
			FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));
			if (diff > 0.0)
				Format(g_szTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
			else
				Format(g_szTimeDifference[client], sizeof(szDiff), "+%s", szDiff);

			// If the server already has a record
			if (g_StyleMapTimesCount[style] > 0)
			{
				if (g_fFinalTime[client] < g_fRecordStyleMapTime[style])
				{
					// New fastest time in map
					g_bStyleMapSRVRecord[style][client] = true;
					g_fRecordStyleMapTime[style] = g_fFinalTime[client];
					Format(g_szRecordStylePlayer[style], 128, "%s", szName);
					FormatTimeFloat(1, g_fRecordStyleMapTime[style], 3, g_szRecordStyleMapTime[style], 64);

					if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
					{
						g_bNewReplay[client] = true;
						g_fReplayTimes[0][style] = g_fFinalTime[client];
						Handle pack;
						CreateDataTimer(3.0, StyleReplayTimer, pack);
						WritePackCell(pack, GetClientUserId(client));
						WritePackCell(pack, style);
					}
				}
			}
			else
			{
				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
				{
					g_bNewReplay[client] = true;
					g_fReplayTimes[0][style] = g_fFinalTime[client];
					Handle pack;
					CreateDataTimer(3.0, StyleReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, style);
				}

				// Has to be the new record, since it is the first completion
				g_bStyleMapSRVRecord[style][client] = true;
				g_fRecordStyleMapTime[style] = g_fFinalTime[client];
				Format(g_szRecordStylePlayer[style], 128, "%s", szName);
				FormatTimeFloat(1, g_fRecordStyleMapTime[style], 3, g_szRecordStyleMapTime[style], 128);
			}


			// Check for personal record
			if (g_fPersonalStyleRecord[style][client] == 0.0)
			{
				// Clients first record
				g_fPersonalStyleRecord[style][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fPersonalStyleRecord[style][client], 3, g_szPersonalStyleRecord[style][client], 128);
				
				g_bStyleMapFirstRecord[style][client] = true;
				g_pr_showmsg[client] = true;
				
				db_selectStyleRecord(client, style);
			}
			else if (diff > 0.0)
			{
				// Client's new record
				g_fPersonalStyleRecord[style][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fPersonalStyleRecord[style][client], 3, g_szPersonalStyleRecord[style][client], 128);

				g_bStyleMapPBRecord[style][client] = true;
				g_pr_showmsg[client] = true;

				db_selectStyleRecord(client, style);
			}

			if (!g_bStyleMapSRVRecord[style][client] && !g_bStyleMapFirstRecord[style][client] && !g_bStyleMapPBRecord[style][client])
			{
				int count = g_StyleMapTimesCount[style];

				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i) && !IsFakeClient(i))
					{
						CPrintToChat(i, "%t", "BPress6", g_szChatPrefix, szName, g_szStyleRecordPrint[style], g_szFinalTime[client], g_szTimeDifference[client], g_StyleMapRank[style][client], count, g_szRecordStyleMapTime[style]);
					}
				}
			}
			CS_SetClientAssists(client, 100);
		}
	}
	else
	{
		/*====================================
		=            Handle Bonus            =
		====================================*/
		if (style == 0)
		{
			if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[zGroup][0] || g_fReplayTimes[zGroup][0] == 0.0))
			{
				if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client])
				{
					g_fReplayTimes[zGroup][0] = g_fFinalTime[client];
					g_bNewBonus[client] = true;
					Handle pack;
					CreateDataTimer(3.0, BonusReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, zGroup);
				}
			}

			char szDiff[54];
			float diff;

			// Record bools init
			g_bBonusFirstRecord[client] = false;
			g_bBonusPBRecord[client] = false;
			g_bBonusSRVRecord[client] = false;

			g_OldMapRankBonus[zGroup][client] = g_MapRankBonus[zGroup][client];

			diff = g_fPersonalRecordBonus[zGroup][client] - g_fFinalTime[client];
			FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));

			if (diff > 0.0)
				Format(g_szBonusTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
			else
				Format(g_szBonusTimeDifference[client], sizeof(szDiff), "+%s", szDiff);


			g_tmpBonusCount[zGroup] = g_iBonusCount[zGroup];

			// If the server already has a record
			if (g_iBonusCount[zGroup] > 0)
			{
				// New fastest time in current bonus
				if (g_fFinalTime[client] < g_fBonusFastest[zGroup])
				{
					g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
					g_fBonusFastest[zGroup] = g_fFinalTime[client];
					Format(g_szBonusFastest[zGroup], 128, "%s", szName);
					FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 128);

					// Update Checkpoints
					if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
					{
						for (int i = 0; i < CPLIMIT; i++)
						{
							g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
						}
						g_bCheckpointRecordFound[zGroup] = true;
					}

					g_bBonusSRVRecord[client] = true;
					if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
					{
						g_bNewBonus[client] = true;
						g_fReplayTimes[zGroup][0] = g_fFinalTime[client];
						Handle pack;
						CreateDataTimer(3.0, BonusReplayTimer, pack);
						WritePackCell(pack, GetClientUserId(client));
						WritePackCell(pack, zGroup);
					}
				}
			}
			else
			{
				// Has to be the new record, since it is the first completion
				if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
				{
					g_bNewBonus[client] = true;
					g_fReplayTimes[zGroup][0] = g_fFinalTime[client];
					Handle pack;
					CreateDataTimer(3.0, BonusReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, zGroup);
				}

				g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
				g_fBonusFastest[zGroup] = g_fFinalTime[client];
				Format(g_szBonusFastest[zGroup], 128, "%s", szName);
				FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 128);

				// Update Checkpoints
				if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
				{
					for (int i = 0; i < CPLIMIT; i++)
						g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
					g_bCheckpointRecordFound[zGroup] = true;
				}

				g_bBonusSRVRecord[client] = true;

				g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
			}

			// Clients first record
			if (g_fPersonalRecordBonus[zGroup][client] == 0.0)
			{
				g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 128);

				g_bBonusFirstRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
				db_insertBonus(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup);
			}

			else if (diff > 0.0)
			{
				// client's new record
				g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 128);

				g_bBonusPBRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
				db_updateBonus(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup);
			}


			if (!g_bBonusSRVRecord[client] && !g_bBonusFirstRecord[client] && !g_bBonusPBRecord[client])
			{
				db_currentBonusRunRank(client, zGroup);
			}
		}
		else if (style != 0)
		{
			if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[zGroup][style] || g_fReplayTimes[zGroup][style] == 0.0))
			{
				if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client])
				{
					g_fReplayTimes[zGroup][style] = g_fFinalTime[client];
					g_bNewBonus[client] = true;
					Handle pack;
					CreateDataTimer(3.0, StyleBonusReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, zGroup);
					WritePackCell(pack, style);
				}
			}

			// styles for bonus
			char szDiff[54];
			float diff;

			// Record bools init
			g_bBonusFirstRecord[client] = false;
			g_bBonusPBRecord[client] = false;
			g_bBonusSRVRecord[client] = false;

			g_StyleOldMapRankBonus[style][zGroup][client] = g_StyleMapRankBonus[style][zGroup][client];

			diff = g_fStylePersonalRecordBonus[style][zGroup][client] - g_fFinalTime[client];
			FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));

			if (diff > 0.0)
				Format(g_szBonusTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
			else
				Format(g_szBonusTimeDifference[client], sizeof(szDiff), "+%s", szDiff);


			g_StyletmpBonusCount[style][zGroup] = g_iStyleBonusCount[style][zGroup];
			
			// If the server already has a record
			if (g_iStyleBonusCount[style][zGroup] > 0)
			{
				if (g_fFinalTime[client] < g_fStyleBonusFastest[style][zGroup])
				{
					// New fastest time in current bonus
					g_fStyleOldBonusRecordTime[style][zGroup] = g_fStyleBonusFastest[style][zGroup];
					g_fStyleBonusFastest[style][zGroup] = g_fFinalTime[client];
					Format(g_szStyleBonusFastest[style][zGroup], 128, "%s", szName); // fluffys come back stopped here
					FormatTimeFloat(1, g_fStyleBonusFastest[style][zGroup], 3, g_szStyleBonusFastestTime[style][zGroup], 128);

					g_bBonusSRVRecord[client] = true;
					if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
					{
						g_bNewBonus[client] = true;
						g_fReplayTimes[zGroup][style] = g_fFinalTime[client];
						Handle pack;
						CreateDataTimer(3.0, StyleBonusReplayTimer, pack);
						WritePackCell(pack, GetClientUserId(client));
						WritePackCell(pack, zGroup);
						WritePackCell(pack, style);
					}
				}
			}
			else
			{
				if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
				{
					g_bNewBonus[client] = true;
					g_fReplayTimes[zGroup][style] = g_fFinalTime[client];
					Handle pack;
					CreateDataTimer(3.0, StyleBonusReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, zGroup);
					WritePackCell(pack, style);
				}

				// Has to be the new record, since it is the first completion
				g_fStyleOldBonusRecordTime[style][zGroup] = g_fStyleBonusFastest[style][zGroup];
				g_fStyleBonusFastest[style][zGroup] = g_fFinalTime[client];
				Format(g_szStyleBonusFastest[style][zGroup], 128, "%s", szName);
				FormatTimeFloat(1, g_fStyleBonusFastest[style][zGroup], 3, g_szStyleBonusFastestTime[style][zGroup], 128);

				g_bBonusSRVRecord[client] = true;

				g_fStyleOldBonusRecordTime[style][zGroup] = g_fStyleBonusFastest[style][zGroup];
			}

			// Clients first record
			if (g_fStylePersonalRecordBonus[style][zGroup][client] == 0.0)
			{
				g_fStylePersonalRecordBonus[style][zGroup][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fStylePersonalRecordBonus[style][zGroup][client], 3, g_szStylePersonalRecordBonus[style][zGroup][client], 128);

				g_bBonusFirstRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_insertBonusStyle(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup, style);
			}
			else if (diff > 0.0)
			{
				// client's new record
				g_fStylePersonalRecordBonus[style][zGroup][client] = g_fFinalTime[client];
				FormatTimeFloat(1, g_fStylePersonalRecordBonus[style][zGroup][client], 3, g_szStylePersonalRecordBonus[style][zGroup][client], 128);

				g_bBonusPBRecord[client] = true;
				g_pr_showmsg[client] = true;
				db_updateBonusStyle(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup, style);
			}


			if (!g_bBonusSRVRecord[client] && !g_bBonusFirstRecord[client] && !g_bBonusPBRecord[client])
			{
				db_currentBonusStyleRunRank(client, zGroup, style);
			}
		}
	}

	Client_Stop(client, 1);
	db_deleteTmp(client);
}

// Start Timer
public void CL_OnStartWrcpTimerPress(int client)
{
	if (!g_bSpectate[client] && !g_bNoClip[client] && ((GetGameTime() - g_fLastTimeNoClipUsed[client]) > 2.0))
	{
		int zGroup = g_iClientInZone[client][2];
		if(zGroup != 0)
		{
			return;
		}
		if (zGroup == 0)
		{
			g_fStartWrcpTime[client] = GetGameTime();
			g_fCurrentWrcpRunTime[client] = 0.0;
			g_bWrcpTimeractivated[client] = true;
			g_bNotTeleporting[client] = true;
			g_WrcpStage[client] = g_Stage[0][client];
			Stage_StartRecording(client);
		}
		if (g_Stage[0][client] > 1 && !g_bPracticeMode[client] && !IsFakeClient(client)) {
			char szSpeed[128];
			char preMessage[128];
			Format(szSpeed, sizeof(szSpeed), "%i", RoundToNearest(g_fLastSpeed[client]));
			Format(preMessage, sizeof(preMessage), "%t", "StagePrestrafe", g_szChatPrefix, g_Stage[0][client], szSpeed);
			if (g_iPrespeedText[client])
				CPrintToChat(client, preMessage);
		
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i)) 
					continue;

				if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
					continue;

				int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if(ObserverMode != 4 && ObserverMode != 5)
					continue;

				int ObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				if (ObserverTarget != client)
					continue;

				if (g_iPrespeedText[i])
					CPrintToChat(i, preMessage);
			}
		}
	}
}

// End Timer
public void CL_OnEndWrcpTimerPress(int client, float time2)
{
	if (!IsValidClient(client))
		return;

	// Print bot finishing message to spectators
	if (IsFakeClient(client))
	{
		g_bWrcpTimeractivated[client] = false;
		return;
	}

	int stage = g_WrcpStage[client];
	// Get Client Name
	char szName[128];
	GetClientName(client, szName, 128);

	if (g_bWrcpEndZone[client])
	{
		stage += 1;
		g_bWrcpEndZone[client] = false;
	}

	if (stage > g_TotalStages) // Hack Fix for multiple end zone issue
		stage = g_TotalStages;
	else if (stage < 1)
		stage = 1;

	if (g_bWrcpTimeractivated[client] && g_iCurrentStyle[client] == 0)
	{
		// int stage = g_CurrentStage[client];

		g_fFinalWrcpTime[client] = g_fCurrentWrcpRunTime[client];

		if (g_fFinalWrcpTime[client] <= 0.0)
		{
			CPrintToChat(client, "%t", "ErrorStageTime", g_szChatPrefix, stage);
			return;
		}
		//Stage 1 to stage 2 glitch stopper.
		if(g_wrcpStage2Fix[client] && stage == 2){
			g_wrcpStage2Fix[client] = false;
			CPrintToChat(client, "%t", "StageNotRecorded", g_szChatPrefix);
			return;
		}
		
		g_wrcpStage2Fix[client] = false;

		char sz_srDiff[128];
		float time = g_fFinalWrcpTime[client];
		float f_srDiff = (g_fStageRecord[stage] - time);
		FormatTimeFloat(client, f_srDiff, 3, sz_srDiff, 128);
		if (f_srDiff > 0)
		{
			Format(sz_srDiff, 128, "%cSR: %c-%s%c", WHITE, LIGHTGREEN, sz_srDiff, WHITE);
		}
		else
		{
			Format(sz_srDiff, 128, "%cSR: %c+%s%c", WHITE, RED, sz_srDiff, WHITE);
		}

		FormatTimeFloat(client, g_fFinalWrcpTime[client], 3, g_szFinalWrcpTime[client], 32);
		// Make a new stage replay bot?
		if (GetConVarBool(g_hReplaceReplayTime) && (!g_bStageReplay[stage] || g_fFinalWrcpTime[client] < g_fStageReplayTimes[stage]))
		{
			Stage_SaveRecording(client, stage, g_szFinalWrcpTime[client]);
		}
		else
		{
			if (g_TotalStageRecords[stage] > 0)
			{ // If the server already has a record
				if (g_fFinalWrcpTime[client] < g_fStageRecord[stage] && g_fFinalWrcpTime[client] > 0.0)
				{
					Stage_SaveRecording(client, stage, g_szFinalWrcpTime[client]);
				}
			}
			else
			{
				Stage_SaveRecording(client, stage, g_szFinalWrcpTime[client]);
			}
		}

		db_selectWrcpRecord(client, 0, stage);
		g_bWrcpTimeractivated[client] = false;
	}
	else if (g_bWrcpTimeractivated[client] && g_iCurrentStyle[client] != 0) // styles
	{
		int style = g_iCurrentStyle[client];
		g_fFinalWrcpTime[client] = GetGameTime() - g_fStartWrcpTime[client];
		if (g_fFinalWrcpTime[client] <= 0.0)
		{
			CPrintToChat(client, "%t", "ErrorStageTime", g_szChatPrefix, stage);
			return;
		}

		char sz_srDiff[128];
		float time = g_fFinalWrcpTime[client];
		float f_srDiff = (g_fStyleStageRecord[style][stage] - time);
		FormatTimeFloat(client, f_srDiff, 3, sz_srDiff, 128);
		if (f_srDiff > 0)
		{
			Format(sz_srDiff, 128, "%cSR: %c-%s%c", WHITE, LIGHTGREEN, sz_srDiff, WHITE);
		}
		else
		{
			Format(sz_srDiff, 128, "%cSR: %c+%s%c", WHITE, RED, sz_srDiff, WHITE);
		}

		FormatTimeFloat(client, g_fFinalWrcpTime[client], 3, g_szFinalWrcpTime[client], 32);
		db_selectWrcpRecord(client, style, stage);
		g_bWrcpTimeractivated[client] = false;
	}
}
