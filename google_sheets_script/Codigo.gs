const DRIVE_FOLDER_NAME = "Vigilarte_Evidencias";
const SHEET_NAME = "Proyectos_Terreno";

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(15000); // Espera activa de 15 segundos para evitar bloqueos
    
    if (!e || !e.postData || !e.postData.contents) {
      return createJsonResponse({ status: "error", message: "Cuerpo POST vacío recibido." }, 400);
    }

    let payload;
    try {
      payload = JSON.parse(e.postData.contents);
    } catch (parseErr) {
      return createJsonResponse({ status: "error", message: "Fallo al decodificar JSON: " + parseErr.toString() }, 400);
    }

    // Acepta tanto 'contacto' como 'nombre' para compatibilidad con todas las pantallas de Flutter
    const contacto    = payload.contacto || payload.nombre || "N/A";
    const direccion   = payload.direccion || "N/A";
    const celular     = payload.celular || "N/A";
    const correo      = payload.correo || "N/A";
    const proyecto    = payload.proyecto || "General";
    const fecha       = payload.fecha || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");
    const mapa        = payload.mapa || "0.0, 0.0";
    const responsable = payload.responsable || "Fedor Corzano";
    const peligros    = Array.isArray(payload.peligros) 
                          ? payload.peligros.join(", ") 
                          : (payload.peligros || (Array.isArray(payload.riesgos) ? payload.riesgos.join(", ") : payload.riesgos) || (Array.isArray(payload.ssoma) ? payload.ssoma.join(", ") : payload.ssoma) || "Ninguno");
    const estructuras = Array.isArray(payload.estructuras) ? payload.estructuras.join(", ") : (payload.estructuras || "N/A");
    const materiales  = Array.isArray(payload.materiales) ? payload.materiales.join(", ") : (payload.materiales || "N/A");
    const fotoBase64  = payload.fotoBase64 || null;

    let fotoUrl = "SIN_FOTO";
    let driveFileId = null;

    // Guardar imagen en Google Drive si viene en Base64
    if (fotoBase64 && fotoBase64.length > 20) {
      try {
        const driveRes = saveBase64ToDrive(fotoBase64, contacto);
        fotoUrl = driveRes.url;
        driveFileId = driveRes.fileId;
      } catch (err) {
        fotoUrl = "ERROR_DRIVE: " + err.toString();
      }
    }

    // Inicializar hoja y encabezados si está vacía
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      const defaultHeaders = ["CONTACTO", "DIRECCION", "CELULAR", "CORREO", "PROYECTO", "FECHA", "MAPA", "RESPONSABLE", "PELIGROS", "ESTRUCTURAS", "MATERIALES", "URL_FOTO"];
      sheet.appendRow(defaultHeaders);
      sheet.getRange(1, 1, 1, defaultHeaders.length).setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
      sheet.setFrozenRows(1);
    }

    // Normalización de cabeceras (eliminar tildes, mayúsculas y espacios)
    function cleanHeader(str) {
      if (!str) return "";
      return str.toString()
        .toUpperCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .trim();
    }

    const lastCol = Math.max(sheet.getLastColumn(), 1);
    const rawHeaders = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    const headerRow = rawHeaders.map(cleanHeader);
    
    // Detectar posiciones clave
    const idxEstructuras = headerRow.findIndex(h => h.indexOf("ESTRUCTUR") !== -1);
    let idxMateriales = headerRow.findIndex(h => h.indexOf("MATERIAL") !== -1);
    let idxFoto = headerRow.findIndex(h => h.indexOf("FOTO") !== -1 || h.indexOf("EVIDENCIA") !== -1 || h.indexOf("URL") !== -1 || h.indexOf("LINK") !== -1);
    
    // 1. Si la hoja no tiene la columna MATERIALES pero tiene ESTRUCTURAS, la insertamos automáticamente
    if (idxMateriales === -1 && idxEstructuras !== -1) {
      sheet.insertColumnAfter(idxEstructuras + 1);
      sheet.getRange(1, idxEstructuras + 2).setValue("MATERIALES").setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
      headerRow.splice(idxEstructuras + 1, 0, "MATERIALES");
      // Recalcular idxFoto tras insertar columna
      idxFoto = headerRow.findIndex(h => h.indexOf("FOTO") !== -1 || h.indexOf("EVIDENCIA") !== -1 || h.indexOf("URL") !== -1 || h.indexOf("LINK") !== -1);
    }

    // 2. Si la columna de Foto no existe (o fue reemplazada por Materiales), la añadimos al final
    if (idxFoto === -1) {
      const nextCol = headerRow.length + 1;
      sheet.getRange(1, nextCol).setValue("URL_FOTO").setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
      headerRow.push("URL_FOTO");
    }

    // Mapa de valores según la cabecera
    const valueMap = {
      "CONTACTO": contacto,
      "NOMBRE": contacto,
      "CLIENTE": contacto,
      "EMPRESA": contacto,
      "DIRECCION": direccion,
      "CELULAR": celular,
      "TELEFONO": celular,
      "CORREO": correo,
      "EMAIL": correo,
      "PROYECTO": proyecto,
      "FECHA": fecha,
      "MAPA": mapa,
      "GPS": mapa,
      "COORDENADAS": mapa,
      "RESPONSABLE": responsable,
      "PELIGROS": peligros,
      "PELIGRO": peligros,
      "RIESGOS": peligros,
      "RIESGO": peligros,
      "SSOMA": peligros,
      "ESTRUCTURAS": estructuras,
      "ESTRUCTURA": estructuras,
      "MATERIALES": materiales,
      "MATERIAL": materiales,
      "URL_FOTO": fotoUrl,
      "FOTO": fotoUrl,
      "FOTOGRAFIA": fotoUrl,
      "EVIDENCIA": fotoUrl,
      "IMAGEN": fotoUrl,
      "LINK_FOTO": fotoUrl
    };

    // Construir la fila según el orden exacto de las cabeceras de la hoja
    const row = headerRow.map(h => {
      if (valueMap[h] !== undefined) return valueMap[h];
      for (const key in valueMap) {
        if (h.indexOf(key) !== -1 || key.indexOf(h) !== -1) {
          return valueMap[key];
        }
      }
      return "";
    });

    sheet.appendRow(row);

    return createJsonResponse({
      status: "success",
      message: "Proyecto registrado exitosamente en Google Sheets y Drive.",
      data: { row: sheet.getLastRow(), contacto: contacto, fotoUrl: fotoUrl, driveFileId: driveFileId }
    }, 200);

  } catch (err) {
    // Si ocurre cualquier error inesperado, lo devolvemos como JSON legible para que Flutter no falle
    return createJsonResponse({ status: "error", message: "Excepción interna en Apps Script: " + err.toString() }, 500);
  } finally {
    try {
      lock.releaseLock();
    } catch (_) {}
  }
}

function saveBase64ToDrive(base64Data, contacto) {
  let clean = base64Data;
  let mime = "image/png";
  if (base64Data.indexOf("data:") === 0) {
    const parts = base64Data.split(",");
    const m = parts[0].match(/:(.*?);/);
    if (m) mime = m[1];
    clean = parts[1];
  }
  const bytes = Utilities.base64Decode(clean);
  const time = Utilities.formatDate(new Date(), "GMT-5", "yyyyMMdd_HHmmss");
  const fileName = "VIGILARTE_" + contacto.replace(/[^a-zA-Z0-9]/g, "_") + "_" + time + ".png";
  const blob = Utilities.newBlob(bytes, mime, fileName);
  
  let folder;
  const folders = DriveApp.getFoldersByName(DRIVE_FOLDER_NAME);
  folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(DRIVE_FOLDER_NAME);
  
  const file = folder.createFile(blob);
  try {
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  } catch (e) {
    console.warn("No se pudo aplicar permiso público:", e);
  }
  
  return {
    url: "https://drive.google.com/uc?export=view&id=" + file.getId(),
    fileId: file.getId()
  };
}

function doGet(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // Función auxiliar para leer una columna entera de una pestaña específica (ignorando la cabecera)
  function getColumnData(sheetName) {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return [];
    const rows = sheet.getDataRange().getValues();
    let list = [];
    // Empezamos desde la fila 1 (asumiendo cabecera en fila 0)
    for (let i = 1; i < rows.length; i++) {
      if (rows[i][0]) { // Si la celda no está vacía
        list.push(rows[i][0].toString().trim());
      }
    }
    return list;
  }

  // Recolectar las listas de cada pestaña respetando nombres exactos de hojas
  const listaPeligros = getColumnData("Peligros");
  const peligrosFinal = listaPeligros.length > 0 ? listaPeligros : getColumnData("Riesgos");

  const data = {
    proyectos: getColumnData("Proyectos"),
    estructuras: getColumnData("Estructuras"),
    materiales: getColumnData("Materiales"),
    peligros: peligrosFinal,
    riesgos: peligrosFinal
  };

  return createJsonResponse(data, 200);
}

/**
 * Función auxiliar para generar respuestas JSON compatibles con Google Apps Script
 */
function createJsonResponse(data, statusCode) {
  if (statusCode && typeof data === "object" && !Array.isArray(data) && !data.statusCode) {
    data.statusCode = statusCode;
  }
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
