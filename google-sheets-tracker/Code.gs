/**
 * ============================================================================
 * RECALL -- Tracker de Telechargements & Base de Donnees Google Sheets
 * ============================================================================
 * Fichier 100% compatible ASCII/UTF-8 (aucun probleme d'encodage possible)
 * ============================================================================
 */

// Recuperation intelligente de la feuille de telechargements (tolere tout encodage)
function getDownloadsSheet(ss) {
  if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheets = ss.getSheets();
  var bestSheet = null;
  var maxRows = -1;

  for (var i = 0; i < sheets.length; i++) {
    var s = sheets[i];
    var name = s.getName().toLowerCase();
    // Reconnait Telechargements ou nom contenant chargement ou download
    if (name.indexOf("chargement") !== -1 || name.indexOf("download") !== -1) {
      var rows = s.getLastRow();
      if (rows > maxRows) {
        maxRows = rows;
        bestSheet = s;
      }
    }
  }

  if (bestSheet && maxRows > 1) {
    return bestSheet;
  }

  return ss.getSheetByName("T\u00E9l\u00E9chargements") ||
         ss.getSheetByName("Telechargements") ||
         (bestSheet ? bestSheet : null);
}

// Recuperation intelligente du tableau de bord
function getDashboardSheet(ss) {
  if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    var name = sheets[i].getName().toLowerCase();
    if (name.indexOf("tableau") !== -1 || name.indexOf("dashboard") !== -1) {
      return sheets[i];
    }
  }
  return null;
}

// Recuperation intelligente de la feuille de recaps
function getRecapSheet(ss) {
  if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    var name = sheets[i].getName().toLowerCase();
    if (name.indexOf("capitulatif") !== -1 || name.indexOf("recap") !== -1) {
      return sheets[i];
    }
  }
  return null;
}

// Recuperation intelligente de la feuille de retours/suggestions
function getFeedbackSheet(ss) {
  if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    var name = sheets[i].getName().toLowerCase();
    if (name.indexOf("retour") !== -1 || name.indexOf("suggestion") !== -1 || name.indexOf("feedback") !== -1) {
      return sheets[i];
    }
  }
  return null;
}

/**
 * Nettoyage automatique des onglets fantomes corrompus et reparation complete
 * Selectionnez cette fonction dans Apps Script et cliquez sur 'Executer'
 */
function nettoyerEtReparerTout() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheets = ss.getSheets();

  // 1. Trouver la vraie feuille de telechargements (celle avec les vraies lignes)
  var realDownloads = getDownloadsSheet(ss);

  // 2. Supprimer les doublons de Tableau de Bord (ne garder que le principal)
  var allDashboards = [];
  for (var i = 0; i < sheets.length; i++) {
    var n = sheets[i].getName().toLowerCase();
    if (n.indexOf("tableau") !== -1 || n.indexOf("dashboard") !== -1) {
      allDashboards.push(sheets[i]);
    }
  }
  while (allDashboards.length > 1) {
    var extraDash = allDashboards.pop();
    try { ss.deleteSheet(extraDash); } catch(e) {}
  }

  // Supprimer les doublons de Retours & Suggestions (ex: onglet corrompu)
  var allFeedbacks = [];
  for (var i = 0; i < sheets.length; i++) {
    var n = sheets[i].getName().toLowerCase();
    if (n.indexOf("retour") !== -1 || n.indexOf("suggestion") !== -1) {
      allFeedbacks.push(sheets[i]);
    }
  }
  // Si plusieurs onglets retours, garder celui qui est propre
  if (allFeedbacks.length > 1) {
    for (var f = allFeedbacks.length - 1; f >= 0; f--) {
      var fbName = allFeedbacks[f].getName();
      if (/[\u221A\u00FA\u00C4\u00EF\u00F6\u00A9]/.test(fbName) && allFeedbacks.length > 1) {
        try { ss.deleteSheet(allFeedbacks[f]); allFeedbacks.splice(f, 1); } catch(e) {}
      }
    }
  }

  // Supprimer les onglets fantomes corrompus ou Feuille 1 vide
  sheets = ss.getSheets();
  for (var i = sheets.length - 1; i >= 0; i--) {
    var s = sheets[i];
    if (s === realDownloads) continue;
    var name = s.getName();
    var isCorrupted = /[\u221A\u00FA\u00C4\u00EF\u00F6\u00A9]/.test(name) ||
                      name === "Feuille 1" ||
                      name === "Sheet1";
    if (isCorrupted && s.getLastRow() <= 1) {
      try { ss.deleteSheet(s); } catch(e) {}
    }
  }

  // 3. Renommer proprement la feuille de donnees
  if (realDownloads) {
    try { realDownloads.setName("T\u00E9l\u00E9chargements"); } catch (e) {}
  } else {
    realDownloads = ss.insertSheet("T\u00E9l\u00E9chargements");
    var headers = [
      "Date & Heure", "Plateforme", "Fichier", "Version", "Type d'\u00E9v\u00E9nement",
      "Emplacement Clic", "Langue Site", "Langue Nav.", "R\u00E9solution", "R\u00E9f\u00E9rent", "Navigateur / OS"
    ];
    realDownloads.appendRow(headers);
    var hRange = realDownloads.getRange(1, 1, 1, headers.length);
    hRange.setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
    realDownloads.setFrozenRows(1);
  }

  // 4. Mettre en place le Tableau de Bord
  var dashSheet = getDashboardSheet(ss);
  if (!dashSheet) {
    dashSheet = ss.insertSheet("\uD83D\uDCCA Tableau de Bord", 0);
  } else {
    try { dashSheet.setName("\uD83D\uDCCA Tableau de Bord"); } catch (e) {}
  }

  dashSheet.getRange("A1:D1").merge()
    .setValue("\uD83D\uDE80 RECALL \u2014 STATISTIQUES DES T\u00C9L\u00C9CHARGEMENTS")
    .setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold").setFontSize(14).setHorizontalAlignment("center");

  var kpis = [
    ["M\u00E9trique", "Total", "Description"],
    ["Total T\u00E9l\u00E9chargements R\u00E9els", "", "Nombre total de clics sur les fichiers d'installation (.dmg, .zip)"],
    ["T\u00E9l\u00E9chargements macOS", "", "Total des t\u00E9l\u00E9chargements version Mac"],
    ["T\u00E9l\u00E9chargements Windows", "", "Total des t\u00E9l\u00E9chargements version PC Windows"],
    ["Clics d'Intention (Hero / Nav)", "", "Visiteurs ayant cliqu\u00E9 sur les boutons d'appel \u00E0 l'action"],
    ["Total Tous \u00C9v\u00E9nements", "", "Volume global de signaux collect\u00E9s"],
    ["Dernier \u00C9v\u00E9nement", "", "Horodatage de la derni\u00E8re action"]
  ];

  dashSheet.getRange(3, 1, kpis.length, 3).setValues(kpis);
  dashSheet.getRange("A3:C3").setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
  dashSheet.getRange("A4:A10").setFontWeight("bold");
  dashSheet.getRange("B4:B10").setFontWeight("bold").setFontSize(12).setHorizontalAlignment("center").setBackground("#F1F5F9");
  dashSheet.autoResizeColumns(1, 3);

  // 5. Calcul direct des valeurs reelles en fallback immediat
  var dlData = realDownloads.getDataRange().getValues();
  var calcDirect = 0, calcMac = 0, calcWin = 0, calcIntent = 0, lastDate = "Aucun";

  for (var r = 1; r < dlData.length; r++) {
    var ev = String(dlData[r][4] || "").toLowerCase();
    var pl = String(dlData[r][1] || "").toLowerCase();
    var dt = dlData[r][0];

    if (ev.indexOf("direct") !== -1 || (ev.indexOf("chargement") !== -1 && ev.indexOf("intention") === -1)) {
      calcDirect++;
      if (pl.indexOf("mac") !== -1) calcMac++;
      if (pl.indexOf("win") !== -1) calcWin++;
    } else if (ev.indexOf("intention") !== -1 || ev.indexOf("intent") !== -1) {
      calcIntent++;
    }

    if (dt) {
      if (dt instanceof Date) {
        lastDate = Utilities.formatDate(dt, Session.getScriptTimeZone() || "GMT", "yyyy-MM-dd HH:mm:ss");
      } else {
        lastDate = String(dt);
      }
    }
  }

  // Pre-remplissage avec les vrais totaux calcules
  dashSheet.getRange("B4").setValue(calcDirect);
  dashSheet.getRange("B5").setValue(calcMac);
  dashSheet.getRange("B6").setValue(calcWin);
  dashSheet.getRange("B7").setValue(calcIntent);
  dashSheet.getRange("B8").setValue(Math.max(0, dlData.length - 1));
  dashSheet.getRange("B9").setValue(lastDate);

  // 6. Injection des formules dynamiques locales
  reparerFormulesTableau(dashSheet);

  // 7. S'assurer que les onglets Recaps et Feedback sont prets et propres
  var recap = getRecapSheet(ss);
  if (!recap) {
    recap = ss.insertSheet("\uD83D\uDCCA R\u00E9capitulatifs de Mix");
    recap.appendRow(["Date & Heure", "Token / ID", "Titre du Set", "D\u00E9but", "Fin", "Dur\u00E9e Masqu\u00E9e", "Stats JSON"]);
    recap.getRange("A1:G1").setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
    recap.setFrozenRows(1);
  } else {
    try { recap.setName("\uD83D\uDCCA R\u00E9capitulatifs de Mix"); } catch(e) {}
  }

  var fb = getFeedbackSheet(ss);
  if (!fb) {
    fb = ss.insertSheet("\uD83D\uDCA1 Retours & Suggestions");
    fb.appendRow(["Date & Heure", "Cat\u00E9gorie", "Message / Suggestion", "Nom / Pseudo DJ", "Email de contact", "Logiciel DJ", "Provenance", "Version", "Navigateur / OS"]);
    fb.getRange("A1:I1").setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
    fb.setFrozenRows(1);
  } else {
    try { fb.setName("\uD83D\uDCA1 Retours & Suggestions"); } catch(e) {}
  }

  Logger.log("Nettoyage et reparation termines avec succes.");
}

// Alias pour compatibilite avec les boutons d'Apps Script
function reparerTableauDeBord() {
  nettoyerEtReparerTout();
}

function nettoyerClasseur() {
  nettoyerEtReparerTout();
}

function setupSheetsIfNeeded(ss) {
  var dl = getDownloadsSheet(ss);
  var dash = getDashboardSheet(ss);
  if (!dl || !dash) {
    nettoyerEtReparerTout();
  }
}

function reparerFormulesTableau(dashSheet) {
  if (!dashSheet) return;

  var frenchFormulas = [
    '=NB.SI(T\u00E9l\u00E9chargements!E2:E; "*direct*")',
    '=NB.SI.ENS(T\u00E9l\u00E9chargements!B2:B; "*macOS*"; T\u00E9l\u00E9chargements!E2:E; "*direct*")',
    '=NB.SI.ENS(T\u00E9l\u00E9chargements!B2:B; "*Windows*"; T\u00E9l\u00E9chargements!E2:E; "*direct*")',
    '=NB.SI(T\u00E9l\u00E9chargements!E2:E; "*Intention*")',
    '=MAX(0; NBVAL(T\u00E9l\u00E9chargements!A2:A) - 1)',
    '=SI(NBVAL(T\u00E9l\u00E9chargements!A2:A)>1; TEXTE(MAX(T\u00E9l\u00E9chargements!A2:A); "AAAA-MM-JJ HH:mm:ss"); "Aucun")'
  ];

  for (var i = 0; i < frenchFormulas.length; i++) {
    var cell = dashSheet.getRange(4 + i, 2);
    try {
      cell.setFormulaLocal(frenchFormulas[i]);
    } catch(e) {
      try {
        var en = frenchFormulas[i]
          .replace(/NB\.SI\.ENS/g, 'COUNTIFS')
          .replace(/NB\.SI/g, 'COUNTIF')
          .replace(/NBVAL/g, 'COUNTA')
          .replace(/SI/g, 'IF')
          .replace(/TEXTE/g, 'TEXT')
          .replace(/AAAA/g, 'yyyy')
          .replace(/JJ/g, 'dd')
          .replace(/;/g, ',');
        cell.setFormula(en);
      } catch(e2) {}
    }
  }
}

function handleRequest(params) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // Mode reparation manuelle ou a distance (?action=repair ou ?action=clean)
  if (params.action === "repair" || params.action === "clean" || params.action === "reparer" || params.action === "setup") {
    nettoyerEtReparerTout();
    var dl = getDownloadsSheet(ss);
    var rowCount = dl ? Math.max(0, dl.getLastRow() - 1) : 0;
    var outRepair = {
      status: "success",
      message: "Classeur nettoye et repare avec succes",
      totalEvents: rowCount
    };
    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(outRepair) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(outRepair))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Mode lecture des statistiques (?action=stats) pour compteur landing page
  if (params.action === "stats") {
    var downloadSheet = getDownloadsSheet(ss);
    var data = downloadSheet ? downloadSheet.getDataRange().getValues() : [];
    var totalDownloads = 0;
    var macDownloads = 0;
    var winDownloads = 0;
    var intentClicks = 0;

    for (var i = 1; i < data.length; i++) {
      var eventType = String(data[i][4] || "").toLowerCase();
      var platform = String(data[i][1] || "").toLowerCase();

      if (eventType.indexOf("direct") !== -1 || (eventType.indexOf("chargement") !== -1 && eventType.indexOf("intention") === -1)) {
        totalDownloads++;
        if (platform.indexOf("mac") !== -1) macDownloads++;
        if (platform.indexOf("win") !== -1) winDownloads++;
      } else if (eventType.indexOf("intention") !== -1 || eventType.indexOf("intent") !== -1) {
        intentClicks++;
      }
    }

    var statsOut = {
      status: "success",
      totalDownloads: totalDownloads,
      macOS: macDownloads,
      windows: winDownloads,
      intents: intentClicks,
      totalEvents: Math.max(0, data.length - 1)
    };

    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(statsOut) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(statsOut))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Mode enregistrement d'un recapitulatif de mix (?action=save_recap)
  if (params.action === "save_recap" || params.action === "recap") {
    var recapSheet = getRecapSheet(ss);
    if (!recapSheet) {
      nettoyerEtReparerTout();
      recapSheet = getRecapSheet(ss);
    }

    var rDate = new Date();
    var rToken = params.share_token || params.token || params.id || "";
    var rTitle = params.title || "Set Recap";
    var rStart = params.session_start_time || "";
    var rEnd = params.session_end_time || "";
    var rHideDur = params.hide_duration === true || params.hide_duration === "true" || params.hide_duration === 1 || params.hide_duration === "1";
    var rStats = typeof params.stats === "string" ? params.stats : JSON.stringify(params.stats || {});

    if (rToken && recapSheet) {
      var rData = recapSheet.getDataRange().getValues();
      var foundRow = -1;
      for (var r = 1; r < rData.length; r++) {
        if (String(rData[r][1]) === rToken) {
          foundRow = r + 1;
          break;
        }
      }
      if (foundRow > 0) {
        recapSheet.getRange(foundRow, 1, 1, 7).setValues([[rDate, rToken, rTitle, rStart, rEnd, rHideDur, rStats]]);
      } else {
        recapSheet.appendRow([rDate, rToken, rTitle, rStart, rEnd, rHideDur, rStats]);
      }
    }

    var resOut = { status: "success", token: rToken };
    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(resOut) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(resOut))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Mode recuperation d'un recapitulatif de mix (?action=get_recap&token=...)
  if (params.action === "get_recap") {
    var recapSheet = getRecapSheet(ss);
    var targetToken = params.token || params.share_token || params.id || "";
    if (recapSheet && targetToken) {
      var rData = recapSheet.getDataRange().getValues();
      for (var i = 1; i < rData.length; i++) {
        if (String(rData[i][1]) === targetToken) {
          var parsedStats = {};
          try { parsedStats = JSON.parse(rData[i][6]); } catch(e) {}
          var resFound = {
            status: "success",
            recap: {
              share_token: rData[i][1],
              title: rData[i][2],
              session_start_time: rData[i][3],
              session_end_time: rData[i][4],
              hide_duration: rData[i][5],
              stats: parsedStats
            }
          };
          if (params.callback) {
            return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(resFound) + ")")
              .setMimeType(ContentService.MimeType.JAVASCRIPT);
          }
          return ContentService.createTextOutput(JSON.stringify(resFound))
            .setMimeType(ContentService.MimeType.JSON);
        }
      }
    }
    var resNotFound = { status: "error", message: "R\u00E9capitulatif introuvable" };
    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(resNotFound) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(resNotFound))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Mode enregistrement d'un retour ou d'une suggestion (?action=feedback)
  if (params.action === "feedback" || params.type === "feedback" || params.is_feedback === "true" || params.suggestion) {
    var fbSheet = getFeedbackSheet(ss);
    if (!fbSheet) {
      nettoyerEtReparerTout();
      fbSheet = getFeedbackSheet(ss);
    }
    var fbNow = new Date();
    var category = params.category || "Suggestion d'am\u00E9lioration";
    var message = params.message || params.suggestion || "(Message vide)";
    var author = params.author || params.name || "Anonyme";
    var email = params.email || "";
    var software = params.software || "Non pr\u00E9cis\u00E9";
    var source = params.source || "Site web";
    var appVersion = params.version || "1.0.5";
    var userAgent = params.ua || "";

    if (fbSheet) {
      fbSheet.appendRow([
        fbNow, category, message, author, email, software, source, appVersion, userAgent
      ]);
    }

    try {
      var ownerEmail = Session.getEffectiveUser().getEmail();
      if (ownerEmail && ownerEmail.indexOf("@") !== -1) {
        MailApp.sendEmail({
          to: ownerEmail,
          subject: "\uD83D\uDCA1 Nouveau retour Recall : " + category + " (de " + author + ")",
          body: "Salut REVR,\n\nUn nouveau retour a \u00E9t\u00E9 envoy\u00E9 pour Recall (" + source + ") :\n\n" +
                "\u2022 Cat\u00E9gorie : " + category + "\n" +
                "\u2022 DJ / Auteur : " + author + (email ? " (" + email + ")" : "") + "\n" +
                "\u2022 Logiciel DJ : " + software + "\n" +
                "\u2022 Version : " + appVersion + "\n\n" +
                "Message :\n" + message + "\n\n" +
                "---\nConsultez l'onglet '\uD83D\uDCA1 Retours & Suggestions' dans votre Google Sheet Recall."
        });
      }
    } catch (mailErr) {}

    var fbOut = { status: "success", message: "Retour enregistr\u00E9 avec succ\u00E8s" };
    return ContentService.createTextOutput(JSON.stringify(fbOut))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Enregistrement d'un nouvel evenement de telechargement
  var downloadSheet = getDownloadsSheet(ss);
  if (!downloadSheet) {
    nettoyerEtReparerTout();
    downloadSheet = getDownloadsSheet(ss);
  }

  var now = new Date();
  var platform = params.platform || "macOS";
  var file = params.file || (platform.toLowerCase().indexOf("mac") !== -1 ? "Recall.dmg" : "Recall-Windows.zip");
  var version = params.version || "1.0.5";
  var eventType = params.event || "T\u00E9l\u00E9chargement direct";
  var location = params.location || "Section T\u00E9l\u00E9chargement";
  var siteLang = params.site_lang || "FR";
  var browserLang = params.browser_lang || "";
  var resolution = params.resolution || "";
  var referrer = params.referrer || "Direct";
  var userAgent = params.ua || "";

  if (downloadSheet) {
    downloadSheet.appendRow([
      now, platform, file, version, eventType, location, siteLang, browserLang, resolution, referrer, userAgent
    ]);
  }

  var dlOut = {
    status: "success",
    timestamp: now.toISOString(),
    platform: platform,
    file: file
  };

  return ContentService.createTextOutput(JSON.stringify(dlOut))
    .setMimeType(ContentService.MimeType.JSON);
}

function doGet(e) {
  var params = (e && e.parameter) ? e.parameter : {};
  return handleRequest(params);
}

function doPost(e) {
  var params = {};
  if (e && e.parameter) {
    params = e.parameter;
  }
  if (e && e.postData && e.postData.contents) {
    try {
      var json = JSON.parse(e.postData.contents);
      for (var key in json) {
        params[key] = json[key];
      }
    } catch (err) {}
  }
  return handleRequest(params);
}
