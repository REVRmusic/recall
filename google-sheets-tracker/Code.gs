/**
 * ============================================================================
 * RECALL — Tracker de Téléchargements Gratuit via Google Sheets
 * ============================================================================
 * Ce script transforme votre Google Sheet en une base de données gratuite,
 * temps réel et sécurisée pour comptabiliser tous les téléchargements de Recall.
 * 
 * GUIDE D'INSTALLATION RAPIDE (2 MINUTES) :
 * 1. Ouvrez https://sheets.new dans votre navigateur.
 * 2. Renommez le classeur en "Recall — Suivi des Téléchargements".
 * 3. Menu : Extensions > Apps Script.
 * 4. Effacez le code présent et collez tout le contenu de ce fichier.
 * 5. Cliquez sur Enregistrer 💾 (Cmd+S / Ctrl+S).
 * 6. Cliquez en haut à droite sur "Déployer" > "Nouveau déploiement".
 * 7. Cliquez sur l'engrenage ⚙️ à gauche de "Sélectionner le type" > "Application Web".
 * 8. Paramétrez :
 *    - Description : "Tracker Téléchargements Recall"
 *    - Exécuter en tant que : "Moi"
 *    - Qui a accès : "Tout le monde" (IMPORTANT pour recevoir les clics du site)
 * 9. Cliquez sur "Déployer" et autorisez l'accès avec votre compte Google.
 * 10. Copiez l'URL de l'application Web fournie (se terminant par /exec).
 * 11. Collez cette URL dans `docs/assets/js/main.js` :
 *     const GOOGLE_SHEET_TRACKER_URL = "https://script.google.com/macros/s/.../exec";
 * ============================================================================
 */

function setupSheetsIfNeeded(ss) {
  var dataSheet = ss.getSheetByName("Téléchargements");
  if (!dataSheet) {
    dataSheet = ss.insertSheet("Téléchargements");
    var headers = [
      "Date & Heure",
      "Plateforme",
      "Fichier",
      "Version",
      "Type d'événement",
      "Emplacement Clic",
      "Langue Site",
      "Langue Nav.",
      "Résolution",
      "Référent",
      "Navigateur / OS"
    ];
    dataSheet.appendRow(headers);
    var headerRange = dataSheet.getRange(1, 1, 1, headers.length);
    headerRange.setBackground("#0F172A");
    headerRange.setFontColor("#00F0FF");
    headerRange.setFontWeight("bold");
    dataSheet.setFrozenRows(1);
    dataSheet.autoResizeColumns(1, headers.length);
  }

  var dashSheet = ss.getSheetByName("📊 Tableau de Bord");
  if (!dashSheet) {
    dashSheet = ss.insertSheet("📊 Tableau de Bord", 0);
    dashSheet.getRange("A1:D1").merge().setValue("🚀 RECALL — STATISTIQUES DES TÉLÉCHARGEMENTS")
      .setBackground("#0F172A").setFontColor("#00F0FF").setFontWeight("bold").setFontSize(14).setHorizontalAlignment("center");

    var kpis = [
      ["Métrique", "Total", "Description"],
      ["Total Téléchargements Réels", '=NB.SI(\'Téléchargements\'!E2:E; "*Téléchargement*")', "Nombre total de clics sur les fichiers d'installation (.dmg, .zip)"],
      ["Téléchargements macOS", '=NB.SI.ENS(\'Téléchargements\'!B2:B; "*macOS*"; \'Téléchargements\'!E2:E; "*Téléchargement*")', "Total des téléchargements version Mac"],
      ["Téléchargements Windows", '=NB.SI.ENS(\'Téléchargements\'!B2:B; "*Windows*"; \'Téléchargements\'!E2:E; "*Téléchargement*")', "Total des téléchargements version PC Windows"],
      ["Clics d'Intention (Hero / Nav)", '=NB.SI(\'Téléchargements\'!E2:E; "*Intention*")', "Visiteurs ayant cliqué sur les boutons d'appel à l'action"],
      ["Total Tous Événements", '=MAX(0; NBVAL(\'Téléchargements\'!A2:A) - 1)', "Volume global de signaux collectés"],
      ["Dernier Événement", '=SI(NBVAL(\'Téléchargements\'!A2:A)>1; TEXTE(MAX(\'Téléchargements\'!A2:A); "AAAA-MM-JJ HH:mm:ss"); "Aucun")', "Horodatage de la dernière action"]
    ];

    dashSheet.getRange(3, 1, kpis.length, 3).setValues(kpis);
    var kpiHeader = dashSheet.getRange("A3:C3");
    kpiHeader.setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
    dashSheet.getRange("A4:A10").setFontWeight("bold");
    dashSheet.getRange("B4:B10").setFontWeight("bold").setFontSize(12).setHorizontalAlignment("center").setBackground("#F1F5F9");
    dashSheet.autoResizeColumns(1, 3);
  }
}

function handleRequest(params) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  setupSheetsIfNeeded(ss);
  var sheet = ss.getSheetByName("Téléchargements");

  // Mode lecture des statistiques (?action=stats) pour affichage d'un compteur en direct
  if (params.action === "stats") {
    var data = sheet.getDataRange().getValues();
    var totalDownloads = 0;
    var macDownloads = 0;
    var winDownloads = 0;
    var intentClicks = 0;

    for (var i = 1; i < data.length; i++) {
      var eventType = String(data[i][4] || "").toLowerCase();
      var platform = String(data[i][1] || "").toLowerCase();

      if (eventType.indexOf("téléchargement") !== -1 || eventType.indexOf("download") !== -1) {
        totalDownloads++;
        if (platform.indexOf("mac") !== -1) macDownloads++;
        if (platform.indexOf("win") !== -1) winDownloads++;
      } else if (eventType.indexOf("intention") !== -1 || eventType.indexOf("intent") !== -1) {
        intentClicks++;
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      totalDownloads: totalDownloads,
      macOS: macDownloads,
      windows: winDownloads,
      intents: intentClicks,
      totalEvents: Math.max(0, data.length - 1)
    })).setMimeType(ContentService.MimeType.JSON);
  }

  // Enregistrement d'un nouvel événement de téléchargement
  var now = new Date();
  var platform = params.platform || "macOS";
  var file = params.file || (platform.toLowerCase().indexOf("mac") !== -1 ? "Recall.dmg" : "Recall-Windows.zip");
  var version = params.version || "1.0.0";
  var eventType = params.event || "Téléchargement direct";
  var location = params.location || "Section Téléchargement";
  var siteLang = params.site_lang || "FR";
  var browserLang = params.browser_lang || "";
  var resolution = params.resolution || "";
  var referrer = params.referrer || "Direct";
  var userAgent = params.ua || "";

  sheet.appendRow([
    now,
    platform,
    file,
    version,
    eventType,
    location,
    siteLang,
    browserLang,
    resolution,
    referrer,
    userAgent
  ]);

  return ContentService.createTextOutput(JSON.stringify({
    status: "success",
    timestamp: now.toISOString(),
    platform: platform,
    file: file
  })).setMimeType(ContentService.MimeType.JSON);
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
