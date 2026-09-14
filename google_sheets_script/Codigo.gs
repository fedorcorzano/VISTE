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

    // Datos del proyecto y sesión
    const contacto    = payload.contacto || payload.nombre || "N/A";
    const direccion   = payload.direccion || "N/A";
    const celular     = payload.celular || "N/A";
    const correo      = payload.correo || "N/A";
    const proyecto    = payload.proyecto || "General";
    const numFoto     = payload.numFoto || 1;
    const areaSector  = payload.areaSector || payload.area || ("Foto #" + numFoto);
    const fecha       = payload.fecha || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");
    const mapa        = payload.mapa || "0.0, 0.0";
    const responsable = payload.responsable || "Fedor Corzano";
    const peligros    = Array.isArray(payload.peligros) 
                          ? payload.peligros.join(", ") 
                          : (payload.peligros || (Array.isArray(payload.riesgos) ? payload.riesgos.join(", ") : payload.riesgos) || (Array.isArray(payload.ssoma) ? payload.ssoma.join(", ") : payload.ssoma) || "Ninguno");
    const estructuras = Array.isArray(payload.estructuras) ? payload.estructuras.join(", ") : (payload.estructuras || "N/A");
    const materiales  = Array.isArray(payload.materiales) ? payload.materiales.join(", ") : (payload.materiales || "N/A");
    const herramientas = Array.isArray(payload.herramientas) ? payload.herramientas.join(", ") : (payload.herramientas || "N/A");
    const accesorios  = Array.isArray(payload.accesorios) ? payload.accesorios.join(", ") : (payload.accesorios || "N/A");
    const fotoBase64  = payload.fotoBase64 || null;

    let fotoUrl = "SIN_FOTO";
    let driveFileId = null;

    // Guardar imagen en Google Drive si viene en Base64
    if (fotoBase64 && fotoBase64.length > 20) {
      try {
        const driveRes = saveBase64ToDrive(fotoBase64, contacto, areaSector);
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
      const defaultHeaders = [
        "CONTACTO", "DIRECCION", "CELULAR", "CORREO", "PROYECTO",
        "AREA_SECTOR", "FECHA", "MAPA", "RESPONSABLE", "PELIGROS",
        "ESTRUCTURAS", "MATERIALES", "HERRAMIENTAS", "ACCESORIOS", "URL_FOTO"
      ];
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
    let rawHeaders = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    let headerRow = rawHeaders.map(cleanHeader);

    // Asegurar que las columnas nuevas existan dinámicamente
    function ensureColumnExists(colName, afterColName) {
      const cleanTarget = cleanHeader(colName);
      if (!headerRow.some(h => h.indexOf(cleanTarget) !== -1)) {
        let insertIdx = -1;
        if (afterColName) {
          const cleanAfter = cleanHeader(afterColName);
          insertIdx = headerRow.findIndex(h => h.indexOf(cleanAfter) !== -1);
        }
        if (insertIdx !== -1) {
          sheet.insertColumnAfter(insertIdx + 1);
          sheet.getRange(1, insertIdx + 2).setValue(colName).setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
          headerRow.splice(insertIdx + 1, 0, cleanTarget);
        } else {
          const nextCol = sheet.getLastColumn() + 1;
          sheet.getRange(1, nextCol).setValue(colName).setBackground("#1E293B").setFontColor("#FFFFFF").setFontWeight("bold");
          headerRow.push(cleanTarget);
        }
      }
    }

    ensureColumnExists("AREA_SECTOR", "PROYECTO");
    ensureColumnExists("HERRAMIENTAS", "MATERIALES");
    ensureColumnExists("ACCESORIOS", "HERRAMIENTAS");
    ensureColumnExists("URL_FOTO");

    // Re-leer cabeceras finales
    const finalCols = Math.max(sheet.getLastColumn(), 1);
    rawHeaders = sheet.getRange(1, 1, 1, finalCols).getValues()[0];
    headerRow = rawHeaders.map(cleanHeader);

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
      "AREA_SECTOR": areaSector,
      "AREA": areaSector,
      "SECTOR": areaSector,
      "NUM_FOTO": numFoto,
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
      "HERRAMIENTAS": herramientas,
      "HERRAMIENTA": herramientas,
      "ACCESORIOS": accesorios,
      "ACCESORIO": accesorios,
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
      message: "Evidencia #" + numFoto + " (" + areaSector + ") registrada exitosamente en Google Sheets y Drive.",
      data: { row: sheet.getLastRow(), contacto: contacto, areaSector: areaSector, fotoUrl: fotoUrl, driveFileId: driveFileId }
    }, 200);

  } catch (err) {
    return createJsonResponse({ status: "error", message: "Excepción interna en Apps Script: " + err.toString() }, 500);
  } finally {
    try {
      lock.releaseLock();
    } catch (_) {}
  }
}

function saveBase64ToDrive(base64Data, contacto, areaSector) {
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
  const cleanContacto = contacto.replace(/[^a-zA-Z0-9]/g, "_");
  const cleanArea = (areaSector || "Foto").replace(/[^a-zA-Z0-9]/g, "_");
  const fileName = "VISTEC_" + cleanContacto + "_" + cleanArea + "_" + time + ".png";
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

// Inicialización de pestañas técnicas maestras (si no existen en la hoja de cálculo)
function initTechnicalTabs(ss) {
  if (!ss) {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  }
  const materialesCols = [
    "Canaletas", "Tubo PVC SEL", "Corrugado PVC", "Tubo PVC SAP",
    "Tubo EMT", "Tubo IMC", "Corrugado EMT", "Corrugado Liquid Tight"
  ];

  const estructurasCols = [
    "Concreto", "Ladrillo Hueco", "Ladrillo Macizo", "Drywall",
    "Mayólica", "Vidrio", "Fierro", "Acero Inoxidable", "Policarbonato", "Teja"
  ];

  // 1. Pestaña ACCESORIOS_MATERIAL
  let sAcc = ss.getSheetByName("ACCESORIOS_MATERIAL");
  if (!sAcc) {
    sAcc = ss.insertSheet("ACCESORIOS_MATERIAL");
    sAcc.appendRow(materialesCols);
    sAcc.getRange(1, 1, 1, materialesCols.length).setBackground("#14532D").setFontColor("#FFFFFF").setFontWeight("bold");
    
    // Accesorios prioritarios
    const accData = [
      ["Codos planos para canaleta", "Conectores PVC SEL", "Conectores corrugado PVC", "Conectores PVC SAP", "Conectores EMT rectos", "Conectores IMC roscados", "Conectores rectos flexible", "Conectores herméticos rectos"],
      ["Uniones para canaleta", "Uniones PVC SEL", "Cajas de paso PVC", "Uniones PVC SAP", "Uniones EMT", "Uniones IMC roscadas", "Conectores curvos 90° flexible", "Conectores herméticos 90°"],
      ["Ángulos internos/externos", "Curvas PVC SEL 90°", "Uniones corrugado", "Curvas PVC SAP 90°", "Abrazaderas Conduit/Unistrut", "Abrazaderas pesadas Unistrut", "Abrazaderas metálicas", "Empaquetaduras herméticas"],
      ["Tees de derivación", "Cajas de paso PVC", "Cinta aislante/vulcanizada", "Cajas de paso SAP", "Curvas EMT 90° preformadas", "Cajas Conduit (Condulet)", "Uniones flexible a rígido", "Cajas de paso herméticas IP65/66"],
      ["Tapas terminales", "Pegamento para PVC", "Abrazaderas plásticas", "Pegamento PVC alta presión", "Cajas de paso F°G°", "Boquillas y contratuercas", "", "Abrazaderas intemperie"],
      ["Cinta doble contacto", "Abrazaderas tipo omega", "", "Abrazaderas metálicas U", "Boquillas terminales", "Sellador de roscas", "", ""],
      ["Tarugos y tornillos", "", "", "", "Riel Unistrut", "", "", ""]
    ];
    accData.forEach(row => sAcc.appendRow(row));
    sAcc.setFrozenRows(1);
  } else {
    // Si ya existe, actualiza los encabezados de la fila 1 al formato limpio
    sAcc.getRange(1, 1, 1, materialesCols.length).setValues([materialesCols]);
  }

  // 2. Pestaña HERRAMIENTAS_MATERIAL
  let sToolMat = ss.getSheetByName("HERRAMIENTAS_MATERIAL");
  if (!sToolMat) {
    sToolMat = ss.insertSheet("HERRAMIENTAS_MATERIAL");
    sToolMat.appendRow(materialesCols);
    sToolMat.getRange(1, 1, 1, materialesCols.length).setBackground("#047857").setFontColor("#FFFFFF").setFontWeight("bold");

    const toolMatData = [
      ["Tijera cortacanaletas/Ingletadora", "Sierra/Cortador PVC", "Cúter/Cuchilla", "Cortatubos PVC/Sierra arco", "Doblador tubo EMT (Curvadora)", "Terraja roscadora IMC", "Sierra metal diente fino", "Cúter/Sierra cubierta plástica"],
      ["Nivel de mano/Láser", "Soplete/Decapador térmico", "Guía pasacables nylon", "Soplete/Pistola calor", "Sierra para metales/Cortatubos", "Prensa de cadena/Tornillo banco", "Alicate pelacables/corte", "Llave inglesa/francesa hermética"],
      ["Taladro percutor/Atornillador", "Taladro/Atornillador", "Cinta métrica", "Taladro percutor", "Escariador tubo EMT", "Cortatubos metal pesado", "Destornillador plano/cruz", "Guía pasacables de acero"],
      ["Cinta métrica/Flexómetro", "Escariador/Lima", "Alicate universal", "Escariador", "Taladro percutor con brocas", "Curvadora hidráulica IMC", "Guía pasacables", "Destornillador"],
      ["Lima para desbaste", "Flexómetro", "", "Nivel de gota", "Atornillador de impacto", "Llave Stilson", "", ""],
      ["", "", "", "", "Nivel torpedo magnético", "Aceite para roscar", "", ""],
      ["", "", "", "", "Flexómetro", "Taladro percutor", "", ""]
    ];
    toolMatData.forEach(row => sToolMat.appendRow(row));
    sToolMat.setFrozenRows(1);
  } else {
    sToolMat.getRange(1, 1, 1, materialesCols.length).setValues([materialesCols]);
  }

  // 3. Pestaña HERRAMIENTAS_ESTRUCTURA
  let sStruct = ss.getSheetByName("HERRAMIENTAS_ESTRUCTURA") || ss.getSheetByName("HERRAMIENTAS ESTRUCTURA");
  if (!sStruct) {
    sStruct = ss.insertSheet("HERRAMIENTAS_ESTRUCTURA");
    sStruct.appendRow(estructurasCols);
    sStruct.getRange(1, 1, 1, estructurasCols.length).setBackground("#0369A1").setFontColor("#FFFFFF").setFontWeight("bold");

    const toolStructData = [
      ["Rotomartillo SDS Plus/Max", "Taladro percusión suave/sin percusión", "Rotomartillo/Taladro percutor", "Atornillador inalámbrico drywall", "Broca diamantada/carburo tungsteno", "Ventosas dobles sujeción vidrio", "Taladro brocas metal HSS/Cobalto", "Brocas especiales Cobalto HSS-Co", "Sierra caladora diente fino plástico", "Amoladora disco diamantado continuo"],
      ["Brocas SDS percusión concreto", "Brocas para ladrillo hueco", "Brocas para mampostería maciza", "Cúter profesional/Serrucho yeso", "Taladro vel. variable (sin percusión)", "Pistola calafateo silicona estructural", "Amoladora angular corte/desbaste", "Amoladora discos para inox", "Taladro broca acrílico/plástico", "Taladro brocas cerámica/teja"],
      ["Cincel plano/Punta demoledora", "Atornillador torque regulable", "Cincel de desbaste", "Puntas Phillips PH2 con tope", "Rociador agua (refrigeración)", "Rascador/Cúter de precisión", "Remachadora manual/neumática", "Pasta decapante/limpiador inox", "Cúter resistente", "Cincel fino manual"],
      ["Llave impacto/Llaves de dado", "Nivel de mano", "Martillo", "Nivel magnético", "Cinta masking tape (anti-desliz)", "Paño microfibra y limpiador", "Llaves de corona/fijas", "Taladro baja vel. con lubricante", "Pistola de silicona neutra", "Pistola calafateo sellador poliuretano"],
      ["Martillo/Comba pequeña", "", "", "Detector de perfiles metálicos", "Nivel de gota", "", "Punzón de centro/Granete", "Llaves especiales para inox", "", ""],
      ["Extensión eléctrica industrial", "", "", "", "", "", "Cepillo de alambre", "", "", ""]
    ];
    toolStructData.forEach(row => sStruct.appendRow(row));
    sStruct.setFrozenRows(1);
  } else {
    sStruct.getRange(1, 1, 1, estructurasCols.length).setValues([estructurasCols]);
  }
}

// Obtener mapa de columnas y sus elementos prioritarios
function getSheetColumnsMap(ss, sheetName) {
  if (!ss) {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  }
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet && sheetName === "HERRAMIENTAS_ESTRUCTURA") {
    sheet = ss.getSheetByName("HERRAMIENTAS ESTRUCTURA");
  }
  if (!sheet) return {};
  const data = sheet.getDataRange().getValues();
  if (data.length < 1) return {};
  const headers = data[0];
  const map = {};
  for (let col = 0; col < headers.length; col++) {
    const colName = headers[col] ? headers[col].toString().trim() : "";
    if (!colName) continue;
    const items = [];
    for (let row = 1; row < data.length; row++) {
      const val = data[row][col] ? data[row][col].toString().trim() : "";
      if (val) {
        items.push(val);
      }
    }
    map[colName] = items;
  }
  return map;
}

function doGet(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // Asegurar que las pestañas técnicas existan
  try {
    initTechnicalTabs(ss);
  } catch (initErr) {
    console.warn("No se pudieron inicializar automáticamente las pestañas:", initErr);
  }

  // Función auxiliar para leer una columna entera de una pestaña simple
  function getColumnData(sheetName) {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return [];
    const rows = sheet.getDataRange().getValues();
    let list = [];
    for (let i = 1; i < rows.length; i++) {
      if (rows[i][0]) {
        list.push(rows[i][0].toString().trim());
      }
    }
    return list;
  }

  const listaPeligros = getColumnData("Peligros");
  const peligrosFinal = listaPeligros.length > 0 ? listaPeligros : getColumnData("Riesgos");

  const accesoriosMaterial = getSheetColumnsMap(ss, "ACCESORIOS_MATERIAL");
  const herramientasMaterial = getSheetColumnsMap(ss, "HERRAMIENTAS_MATERIAL");
  const herramientasEstructura = getSheetColumnsMap(ss, "HERRAMIENTAS_ESTRUCTURA");

  // Materiales y estructuras pueden provenir de las cabeceras de las pestañas técnicas o de pestañas simples
  const matKeys = Object.keys(accesoriosMaterial).length > 0 
                    ? Object.keys(accesoriosMaterial) 
                    : (Object.keys(herramientasMaterial).length > 0 ? Object.keys(herramientasMaterial) : getColumnData("Materiales"));

  const structKeys = Object.keys(herramientasEstructura).length > 0 
                      ? Object.keys(herramientasEstructura) 
                      : getColumnData("Estructuras");

  const data = {
    proyectos: getColumnData("Proyectos"),
    estructuras: structKeys,
    materiales: matKeys,
    peligros: peligrosFinal,
    riesgos: peligrosFinal,
    accesoriosMaterial: accesoriosMaterial,
    herramientasMaterial: herramientasMaterial,
    herramientasEstructura: herramientasEstructura
  };

  return createJsonResponse(data, 200);
}

function createJsonResponse(data, statusCode) {
  if (statusCode && typeof data === "object" && !Array.isArray(data) && !data.statusCode) {
    data.statusCode = statusCode;
  }
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

