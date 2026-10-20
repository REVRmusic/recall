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

// Statuts ecrits dans la colonne O (Statut Utilisateur) de l'onglet Telechargements
var STATUT_UNIQUE = "Unique (1er T\u00E9l\u00E9chargement)";
var STATUT_DOUBLON = "R\u00E9-t\u00E9l\u00E9chargement (Doublon filtr\u00E9)";
var STATUT_INTENTION = "Intention";
var STATUT_IGNORE = "Ignor\u00E9 (requ\u00EAte sans navigateur)";

function estEvenementTelechargement(eventType) {
  var ev = String(eventType || "").toLowerCase();
  if (ev.indexOf("intention") !== -1 || ev.indexOf("intent") !== -1) return false;
  return ev.indexOf("direct") !== -1 || ev.indexOf("unique") !== -1 || ev.indexOf("chargement") !== -1;
}

function estEvenementIntention(eventType) {
  var ev = String(eventType || "").toLowerCase();
  return ev.indexOf("intention") !== -1 || ev.indexOf("intent") !== -1;
}

// Un utilisateur est reconnu par l'ID stocke dans son navigateur OU par son nom de DJ.
// Les anciennes lignes sans ID ni nom retombent sur l'empreinte navigateur + resolution.
function clesUtilisateur(deviceId, djName, userAgent, resolution) {
  var cles = [];
  var dev = String(deviceId || "").trim();
  var dj = String(djName || "").trim().toLowerCase();
  if (dev) cles.push("dev:" + dev);
  if (dj && dj !== "anonyme") cles.push("dj:" + dj);
  if (cles.length === 0) cles.push("fp:" + String(userAgent || "") + "_" + String(resolution || ""));
  return cles;
}

/**
 * Source unique de verite pour tous les compteurs (landing, console admin, tableau de bord).
 * Le statut deja ecrit en colonne O est prioritaire ; sinon il est deduit chronologiquement.
 */
function analyserTelechargements(data) {
  var dejaVus = {};
  var statuts = [];
  var stats = { uniques: 0, mac: 0, windows: 0, doublons: 0, intentions: 0, ignores: 0, bruts: 0 };

  for (var r = 1; r < data.length; r++) {
    var row = data[r];
    if (!row || !row[0]) { statuts[r] = ""; continue; }

    var ev = row[4];
    var statut = "";

    if (estEvenementIntention(ev)) {
      statut = STATUT_INTENTION;
      stats.intentions++;
    } else if (estEvenementTelechargement(ev)) {
      var ua = String(row[10] || "").trim();
      if (!ua) {
        // Appels sans navigateur (ex: ancienne console admin) : jamais comptes comme telechargement
        statut = STATUT_IGNORE;
        stats.ignores++;
      } else {
        stats.bruts++;
        var cles = clesUtilisateur(row[13], row[11], ua, row[8]);
        var dejaVu = false;
        for (var c = 0; c < cles.length; c++) {
          if (dejaVus[cles[c]]) dejaVu = true;
          dejaVus[cles[c]] = true;
        }

        var statutStocke = String(row[14] || "");
        var estUnique;
        if (statutStocke.indexOf("Unique") === 0) estUnique = true;
        else if (statutStocke.indexOf("R\u00E9-t") === 0) estUnique = false;
        else estUnique = !dejaVu;

        if (estUnique) {
          statut = STATUT_UNIQUE;
          stats.uniques++;
          var pl = String(row[1] || "").toLowerCase();
          if (pl.indexOf("mac") !== -1) stats.mac++;
          if (pl.indexOf("win") !== -1) stats.windows++;
        } else {
          statut = STATUT_DOUBLON;
          stats.doublons++;
        }
      }
    }

    statuts[r] = statut;
  }

  return { statuts: statuts, stats: stats, dejaVus: dejaVus };
}

/**
 * Nettoyage automatique des onglets fantomes corrompus et reparation complete
 * Selectionnez cette fonction dans Apps Script et cliquez sur 'Executer'
 */
function nettoyerEtReparerTout() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. Trouver d'abord la vraie feuille de telechargements (la seule a ne JAMAIS toucher)
  var realDownloads = getDownloadsSheet(ss);
  if (realDownloads) {
    try { realDownloads.setName("T\u00E9l\u00E9chargements"); } catch(e) {}
    try {
      if (realDownloads.getLastColumn() < 16) {
        var curCols = realDownloads.getLastColumn();
        if (curCols < 13) {
          realDownloads.getRange(1, 12, 1, 2).setValues([["Nom DJ / Artiste", "Ville / Pays"]]);
        }
        realDownloads.getRange(1, 14, 1, 3).setValues([["ID Appareil / Client ID", "Statut Utilisateur", "Mod\u00E8le Appareil"]]);
        realDownloads.getRange(1, 12, 1, 5).setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
      }
    } catch(eCol) {}
  } else {
    realDownloads = ss.insertSheet("T\u00E9l\u00E9chargements");
    var headers = [
      "Date & Heure", "Plateforme", "Fichier", "Version", "Type d'\u00E9v\u00E9nement",
      "Emplacement Clic", "Langue Site", "Langue Nav.", "R\u00E9solution", "R\u00E9f\u00E9rent", "Navigateur / OS",
      "Nom DJ / Artiste", "Ville / Pays", "ID Appareil / Client ID", "Statut Utilisateur", "Mod\u00E8le Appareil"
    ];
    realDownloads.appendRow(headers);
    var hRange = realDownloads.getRange(1, 1, 1, headers.length);
    hRange.setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
    realDownloads.setFrozenRows(1);
  }

  var realId = realDownloads.getSheetId();

  // 2. Supprimer les doublons et feuilles fantomes en une seule passe securisee
  var sheets = ss.getSheets();
  var keptDashboardId = null;
  var keptFeedbackId = null;
  var keptRecapId = null;

  for (var i = sheets.length - 1; i >= 0; i--) {
    try {
      var s = sheets[i];
      if (!s) continue;
      var sId = s.getSheetId();
      if (sId === realId) continue; // Ne jamais supprimer les telechargements

      var name = s.getName();
      var lower = name.toLowerCase();

      // Detection Tableau de Bord
      if (lower.indexOf("tableau") !== -1 || lower.indexOf("dashboard") !== -1) {
        if (!keptDashboardId) {
          keptDashboardId = sId;
        } else {
          try { ss.deleteSheet(s); } catch(delErr) {}
          continue;
        }
      }

      // Detection Retours & Suggestions
      if (lower.indexOf("retour") !== -1 || lower.indexOf("suggestion") !== -1) {
        if (/[\u221A\u00FA\u00C4\u00EF\u00F6\u00A9]/.test(name)) {
          try { ss.deleteSheet(s); } catch(delErr) {}
          continue;
        }
        if (!keptFeedbackId) {
          keptFeedbackId = sId;
        } else {
          try { ss.deleteSheet(s); } catch(delErr) {}
          continue;
        }
      }

      // Detection Recaps
      if (lower.indexOf("capitulatif") !== -1 || lower.indexOf("recap") !== -1) {
        if (!keptRecapId) {
          keptRecapId = sId;
        } else {
          try { ss.deleteSheet(s); } catch(delErr) {}
          continue;
        }
      }

      // Feuilles vides ou corrompues
      var isCorrupted = /[\u221A\u00FA\u00C4\u00EF\u00F6\u00A9]/.test(name) ||
                        name === "Feuille 1" ||
                        name === "Sheet1";
      if (isCorrupted && s.getLastRow() <= 1) {
        try { ss.deleteSheet(s); } catch(delErr) {}
      }
    } catch(sheetErr) {}
  }

  // 3. Mettre en place le Tableau de Bord
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
    ["Total T\u00E9l\u00E9chargements Uniques", "", "Nombre de personnes / appareils uniques ayant t\u00E9l\u00E9charg\u00E9 (1 par utilisateur)"],
    ["T\u00E9l\u00E9chargements macOS (Uniques)", "", "Total des utilisateurs uniques version Mac"],
    ["T\u00E9l\u00E9chargements Windows (Uniques)", "", "Total des utilisateurs uniques version PC Windows"],
    ["R\u00E9-t\u00E9l\u00E9chargements (Doublons filtr\u00E9s)", "", "Clics r\u00E9p\u00E9t\u00E9s d'utilisateurs d\u00E9j\u00E0 comptabilis\u00E9s"],
    ["Clics d'Intention (Hero / Nav)", "", "Visiteurs ayant cliqu\u00E9 sur les boutons d'appel \u00E0 l'action"],
    ["Total Tous \u00C9v\u00E9nements", "", "Volume global de signaux collect\u00E9s"],
    ["Dernier \u00C9v\u00E9nement", "", "Horodatage de la derni\u00E8re action"]
  ];

  dashSheet.getRange(3, 1, kpis.length, 3).setValues(kpis);
  dashSheet.getRange("A3:C3").setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
  dashSheet.getRange("A4:A11").setFontWeight("bold");
  dashSheet.getRange("B4:B11").setFontWeight("bold").setFontSize(12).setHorizontalAlignment("center").setBackground("#F1F5F9");
  dashSheet.autoResizeColumns(1, 3);

  // 4. Calcul direct des valeurs reelles (dedoublonnage par utilisateur / appareil)
  var dlData = realDownloads.getDataRange().getValues();
  var analyse = analyserTelechargements(dlData);
  var calcDirect = analyse.stats.uniques;
  var calcMac = analyse.stats.mac;
  var calcWin = analyse.stats.windows;
  var calcIntent = analyse.stats.intentions;
  var calcDuplicates = analyse.stats.doublons;
  var lastDate = "Aucun";

  // Les anciennes lignes recoivent leur statut en colonne O pour que les formules du tableau restent justes
  if (dlData.length > 1) {
    var colStatuts = [];
    for (var s = 1; s < dlData.length; s++) {
      colStatuts.push([analyse.statuts[s] || String(dlData[s][14] || "")]);
    }
    realDownloads.getRange(2, 15, colStatuts.length, 1).setValues(colStatuts);
  }

  for (var r = 1; r < dlData.length; r++) {
    var dt = dlData[r][0];
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
  dashSheet.getRange("B7").setValue(calcDuplicates);
  dashSheet.getRange("B8").setValue(calcIntent);
  dashSheet.getRange("B9").setValue(Math.max(0, dlData.length - 1));
  dashSheet.getRange("B10").setValue(lastDate);

  // 5. Injection des formules dynamiques locales
  reparerFormulesTableau(dashSheet);

  // 6. Securite visuelle anti-erreur : si une formule produit #ERROR!, remettre la valeur calculee
  var values = [calcDirect, calcMac, calcWin, calcDuplicates, calcIntent, Math.max(0, dlData.length - 1), lastDate];
  for (var v = 0; v < values.length; v++) {
    try {
      var c = dashSheet.getRange(4 + v, 2);
      var disp = String(c.getDisplayValue() || "");
      if (disp.indexOf("#") !== -1 || disp === "") {
        c.setValue(values[v]);
      }
    } catch(errVal) {}
  }

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

  // Une formule par ligne B4 -> B10, dans le meme ordre que le tableau kpis
  var frenchFormulas = [
    '=NB.SI(T\u00E9l\u00E9chargements!O2:O; "Unique*")',
    '=NB.SI.ENS(T\u00E9l\u00E9chargements!B2:B; "*macOS*"; T\u00E9l\u00E9chargements!O2:O; "Unique*")',
    '=NB.SI.ENS(T\u00E9l\u00E9chargements!B2:B; "*Windows*"; T\u00E9l\u00E9chargements!O2:O; "Unique*")',
    '=NB.SI(T\u00E9l\u00E9chargements!O2:O; "R\u00E9-t*")',
    '=NB.SI(T\u00E9l\u00E9chargements!E2:E; "*Intention*")',
    '=NBVAL(T\u00E9l\u00E9chargements!A2:A)',
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
    var st = analyserTelechargements(data).stats;

    var statsOut = {
      status: "success",
      totalDownloads: st.uniques,
      totalUniqueUsers: st.uniques,
      totalRawDownloads: st.bruts,
      duplicatesFiltered: st.doublons,
      ignored: st.ignores,
      macOS: st.mac,
      windows: st.windows,
      intents: st.intentions,
      totalEvents: Math.max(0, data.length - 1)
    };

    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(statsOut) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(statsOut))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Mode console administration complete (?action=admin_data ou ?action=admin)
  if (params.action === "admin_data" || params.action === "admin") {
    var dlSheet = getDownloadsSheet(ss);
    var fbSheet = getFeedbackSheet(ss);

    var dlData = dlSheet ? dlSheet.getDataRange().getValues() : [];
    var fbData = fbSheet ? fbSheet.getDataRange().getValues() : [];

    var analyseAdmin = analyserTelechargements(dlData);
    var djsCount = 0;

    var downloadsList = [];
    var djsList = [];

    var formatDateSafe = function(dt) {
      if (!dt) return "";
      if (dt instanceof Date) {
        try {
          return Utilities.formatDate(dt, Session.getScriptTimeZone() || "GMT", "yyyy-MM-dd HH:mm:ss");
        } catch(e) {
          return String(dt);
        }
      }
      return String(dt);
    };

    // Parcours des telechargements (du plus recent au plus ancien)
    for (var i = dlData.length - 1; i >= 1; i--) {
      var row = dlData[i];
      if (!row || row.length === 0 || !row[0]) continue;

      var dtStr = formatDateSafe(row[0]);
      var pl = String(row[1] || "macOS");
      var fi = String(row[2] || "");
      var ver = String(row[3] || "1.0.5");
      var ev = String(row[4] || "T\u00E9l\u00E9chargement direct");
      var loc = String(row[5] || "");
      var sLang = String(row[6] || "FR");
      var bLang = String(row[7] || "");
      var res = String(row[8] || "");
      var ref = String(row[9] || "");
      var ua = String(row[10] || "");
      var dj = String(row[11] || "").trim();
      var city = String(row[12] || "").trim();
      var devId = String(row[13] || "");
      var devModel = String(row[15] || "");

      var userStatus = analyseAdmin.statuts[i] || String(row[14] || "");
      var isUnique = userStatus === STATUT_UNIQUE;

      if (dj || city) {
        if (isUnique) djsCount++;
        djsList.push({
          djName: dj || "Anonyme",
          djCity: city || "Non pr\u00E9cis\u00E9",
          platform: pl,
          date: dtStr,
          version: ver,
          deviceId: devId,
          isUnique: isUnique
        });
      }

      downloadsList.push({
        date: dtStr,
        platform: pl,
        file: fi,
        version: ver,
        eventType: ev,
        location: loc,
        siteLang: sLang,
        browserLang: bLang,
        resolution: res,
        referrer: ref,
        userAgent: ua,
        djName: dj,
        djCity: city,
        deviceId: devId,
        statusUser: userStatus,
        deviceModel: devModel,
        isUnique: isUnique
      });
    }

    // Parcours des retours & suggestions (du plus recent au plus ancien)
    var feedbacksList = [];
    for (var j = fbData.length - 1; j >= 1; j--) {
      var fbRow = fbData[j];
      if (!fbRow || fbRow.length === 0 || !fbRow[0]) continue;

      feedbacksList.push({
        date: formatDateSafe(fbRow[0]),
        category: String(fbRow[1] || "Suggestion"),
        message: String(fbRow[2] || ""),
        author: String(fbRow[3] || "Anonyme"),
        email: String(fbRow[4] || ""),
        software: String(fbRow[5] || "Non pr\u00E9cis\u00E9"),
        source: String(fbRow[6] || "Site web"),
        version: String(fbRow[7] || "1.0.5"),
        userAgent: String(fbRow[8] || "")
      });
    }

    var adminOut = {
      status: "success",
      timestamp: new Date().toISOString(),
      stats: {
        totalDownloads: analyseAdmin.stats.uniques,
        totalUniqueUsers: analyseAdmin.stats.uniques,
        totalRawDownloads: analyseAdmin.stats.bruts,
        duplicatesFiltered: analyseAdmin.stats.doublons,
        ignored: analyseAdmin.stats.ignores,
        macOS: analyseAdmin.stats.mac,
        windows: analyseAdmin.stats.windows,
        intents: analyseAdmin.stats.intentions,
        totalEvents: Math.max(0, dlData.length - 1),
        djsCount: djsCount,
        feedbacksCount: feedbacksList.length
      },
      downloads: downloadsList,
      djs: djsList,
      feedbacks: feedbacksList
    };

    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(adminOut) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(adminOut))
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

  // Seul un vrai clic de telechargement (sans action, avec fichier ou plateforme) peut creer une ligne
  if (params.action || (!params.file && !params.platform)) {
    var refusOut = { status: "error", message: "Action inconnue ou requ\u00EAte incompl\u00E8te : aucun t\u00E9l\u00E9chargement enregistr\u00E9" };
    if (params.callback) {
      return ContentService.createTextOutput(params.callback + "(" + JSON.stringify(refusOut) + ")")
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService.createTextOutput(JSON.stringify(refusOut))
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
  var djName = params.dj_name || params.djName || params.artist || "";
  var djCity = params.dj_city || params.djCity || params.location_dj || params.city || "";
  var deviceId = String(params.device_id || params.client_id || "").trim();
  var deviceModel = String(params.device_name || params.device_model || "").trim();

  // 1 seul telechargement par utilisateur : marqueur du navigateur OU trace deja presente en base
  var isDownload = estEvenementTelechargement(eventType);
  var marqueurNavigateur = params.is_redownload === "1" || params.is_redownload === 1 || params.is_redownload === true;
  var dejaEnBase = false;
  if (isDownload && downloadSheet && downloadSheet.getLastRow() > 1) {
    var vus = analyserTelechargements(downloadSheet.getDataRange().getValues()).dejaVus;
    var clesVisiteur = clesUtilisateur(deviceId, djName, userAgent, resolution);
    for (var cv = 0; cv < clesVisiteur.length; cv++) {
      if (vus[clesVisiteur[cv]]) dejaEnBase = true;
    }
  }
  var isFirstForUser = isDownload && !!userAgent && !marqueurNavigateur && !dejaEnBase;

  var userStatus;
  if (!isDownload) {
    userStatus = STATUT_INTENTION;
  } else if (!userAgent) {
    userStatus = STATUT_IGNORE;
  } else if (isFirstForUser) {
    userStatus = STATUT_UNIQUE;
    eventType = "T\u00E9l\u00E9chargement unique (1er)";
  } else {
    userStatus = STATUT_DOUBLON;
    eventType = "R\u00E9-t\u00E9l\u00E9chargement (existant)";
  }

  if (downloadSheet) {
    try {
      if (downloadSheet.getLastColumn() < 16) {
        var curCols = downloadSheet.getLastColumn();
        if (curCols < 13) {
          downloadSheet.getRange(1, 12, 1, 2).setValues([["Nom DJ / Artiste", "Ville / Pays"]]);
        }
        downloadSheet.getRange(1, 14, 1, 3).setValues([["ID Appareil / Client ID", "Statut Utilisateur", "Mod\u00E8le Appareil"]]);
        downloadSheet.getRange(1, 12, 1, 5).setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold");
      }
    } catch(eCol) {}

    downloadSheet.appendRow([
      now, platform, file, version, eventType, location, siteLang, browserLang, resolution, referrer, userAgent, djName, djCity, deviceId, userStatus, deviceModel
    ]);
  }

  // Notification par e-mail a REVR uniquement si c'est un premier telechargement unique
  if (isFirstForUser && (djName || djCity)) {
    try {
      var ownerEmail = Session.getEffectiveUser().getEmail();
      if (ownerEmail && ownerEmail.indexOf("@") !== -1) {
        MailApp.sendEmail({
          to: ownerEmail,
          subject: "\uD83C\uDFA7 Nouveau t\u00E9l\u00E9chargement Recall : " + (djName || "DJ") + (djCity ? " (" + djCity + ")" : ""),
          body: "Salut REVR,\n\nUn DJ vient de t\u00E9l\u00E9charger Recall pour la 1\u00E8re fois (" + platform + ") :\n\n" +
                "\u2022 Nom DJ / Artiste : " + (djName || "Non pr\u00E9cis\u00E9") + "\n" +
                "\u2022 Ville / Pays : " + (djCity || "Non pr\u00E9cis\u00E9") + "\n" +
                "\u2022 Appareil : " + (deviceModel || "Standard") + " (ID: " + deviceId + ")\n" +
                "\u2022 Plateforme : " + platform + "\n" +
                "\u2022 Fichier : " + file + "\n" +
                "\u2022 Emplacement : " + location + "\n" +
                "\u2022 Date & Heure : " + Utilities.formatDate(now, Session.getScriptTimeZone() || "GMT", "yyyy-MM-dd HH:mm:ss") + "\n\n" +
                "---\nConsultez l'onglet 'T\u00E9l\u00E9chargements' dans votre Google Sheet Recall."
        });
      }
    } catch (mailErr) {}
  }

  var dlOut = {
    status: "success",
    timestamp: now.toISOString(),
    platform: platform,
    file: file,
    isUnique: isFirstForUser,
    userStatus: userStatus,
    deviceId: deviceId
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
