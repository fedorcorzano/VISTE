const DRIVE_FOLDER_NAME = "Vigilarte_Evidencias";
const CATALOG_DRIVE_FOLDER_NAME = "VIGILARTE_CATALOGO_FOTOS";
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

    // Acciones especiales para el Catálogo Visual (Método 1 y Método 2)
    if (payload.action === "upload_catalog_image") {
      return handleUploadCatalogImage(payload);
    }
    if (payload.action === "sync_drive_catalog") {
      return handleSyncDriveCatalog();
    }
    if (payload.action === "submit_supplier_quote") {
      return handleSubmitSupplierQuote(payload);
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

  // 4. Pestaña CATALOGO_VISUAL (Imágenes reales, nombres comerciales y especificaciones ampliables)
  let sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  if (!sVisual) {
    sVisual = ss.insertSheet("CATALOGO_VISUAL");
    const visualHeaders = ["Item", "Categoria", "Nombre Comercial", "Especificacion", "URL Imagen"];
    sVisual.appendRow(visualHeaders);
    sVisual.getRange(1, 1, 1, visualHeaders.length).setBackground("#0F172A").setFontColor("#FFFFFF").setFontWeight("bold");

    const defaultVisualData = [
      ["Rotomartillo SDS Plus / Max", "Herramienta", "Rotomartillo percutor profesional SDS Plus", "Potencia 800W-1000W, encastre SDS Plus, con selector de cincelado y percusión", "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80"],
      ["Doblador de tubo EMT (Hickey / Curvadora)", "Herramienta", "Curvadora manual para tubo EMT / Conduit", "Curvador de aluminio o hierro dúctil con marcas de grados para 3/4\" o 1/2\"", "https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80"],
      ["Amoladora angular con disco de corte y desbaste", "Herramienta", "Esmeril angular / Amoladora 4-1/2\"", "Amoladora 4-1/2\" 850W con guarda protectora y discos de corte", "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80"],
      ["Brocas SDS de percusión para concreto", "Consumible", "Juego de brocas SDS Plus para concreto", "Brocas con punta Widia en medidas 1/4\", 5/16\", 3/8\" y 1/2\"", "https://images.unsplash.com/photo-1572981779307-38b8cabb2407?w=600&auto=format&fit=crop&q=80"],
      ["Tubo EMT", "Material", "Tubería metálica rígida liviana Conduit EMT", "Tiras de 3m acero galvanizado estándar ANSI C80.3", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"],
      ["Canaletas", "Material", "Canaleta decorativa de superficie con división", "Tramos de 2m PVC autoextinguible con adhesivo doble contacto", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"],
      ["Tubo PVC SAP", "Material", "Tubo eléctrico PVC Standard Americano Pesado", "Tiras de 3m con campana para empotrado en piso o concreto", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"],
      ["Corrugado Liquid Tight", "Material", "Tubería metálica flexible hermética Liquid Tight", "Núcleo de acero con recubrimiento de PVC para intemperie IP66", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"],
      ["Codos planos para canaleta", "Accesorio", "Codo plano para canaleta PVC", "Cambio de dirección plano a 90 grados para canaleta", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"],
      ["Conectores EMT rectos", "Accesorio", "Conectores rectos con tornillo para EMT", "Conector de acero o zinc para caja de paso metálica", "https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80"]
    ];
    defaultVisualData.forEach(row => sVisual.appendRow(row));
    sVisual.setFrozenRows(1);
  }
}

// Obtener catálogo visual enriquecido con imágenes de la pestaña CATALOGO_VISUAL
function getCatalogVisualData(ss) {
  if (!ss) {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  }
  const s = ss.getSheetByName("CATALOGO_VISUAL");
  if (!s) return [];
  const rows = s.getDataRange().getValues();
  const list = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (row[0] && row[0].toString().trim()) {
      list.push({
        item: row[0].toString().trim(),
        categoria: row[1] ? row[1].toString().trim() : "",
        nombreComercial: row[2] ? row[2].toString().trim() : "",
        especificacion: row[3] ? row[3].toString().trim() : "",
        urlImagen: row[4] ? row[4].toString().trim() : ""
      });
    }
  }
  return list;
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

// Normalización inteligente para coincidencia difusa (ignora tildes, mayúsculas y caracteres especiales)
function normalizeForMatch(str) {
  if (!str) return "";
  return str.toString()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // Sin tildes
    .replace(/[_\-\/\.\(\)]+/g, " ") // Guiones y barras a espacios
    .replace(/\s+/g, " ")
    .trim();
}

// Método 1: Guardar foto del catálogo capturada desde la app
function handleUploadCatalogImage(payload) {
  const itemName = (payload.itemName || payload.item || "").toString().trim();
  if (!itemName) {
    return createJsonResponse({ status: "error", message: "Nombre de ítem requerido." }, 400);
  }
  const category = (payload.category || payload.categoria || "Herramienta").toString().trim();
  const commercialName = (payload.commercialName || payload.nombreComercial || itemName).toString().trim();
  const specification = (payload.specification || payload.especificacion || "").toString().trim();
  const base64Data = payload.base64Data || payload.fotoBase64;

  if (!base64Data || base64Data.length < 20) {
    return createJsonResponse({ status: "error", message: "Datos de imagen Base64 inválidos o vacíos." }, 400);
  }

  // 1. Guardar en carpeta de Drive VIGILARTE_CATALOGO_FOTOS
  const cleanBase64 = base64Data.replace(/^data:image\/\w+;base64,/, "").trim();
  const bytes = Utilities.base64Decode(cleanBase64);
  const blob = Utilities.newBlob(bytes, "image/jpeg", itemName + ".jpg");

  let folder;
  const folders = DriveApp.getFoldersByName(CATALOG_DRIVE_FOLDER_NAME);
  folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(CATALOG_DRIVE_FOLDER_NAME);

  // Reemplazar archivo si ya existía con el mismo nombre
  const existingFiles = folder.getFilesByName(itemName + ".jpg");
  while (existingFiles.hasNext()) {
    existingFiles.next().setTrashed(true);
  }

  const file = folder.createFile(blob);
  try {
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  } catch (e) {
    console.warn("No se pudo aplicar permiso público:", e);
  }

  const directUrl = "https://drive.google.com/uc?export=view&id=" + file.getId();

  // 2. Actualizar o insertar en CATALOGO_VISUAL
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  if (!sVisual) {
    initTechnicalTabs(ss);
    sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  }

  const data = sVisual.getDataRange().getValues();
  let foundRow = -1;
  const cleanTarget = normalizeForMatch(itemName);

  for (let r = 1; r < data.length; r++) {
    const rowItem = (data[r][0] || "").toString().trim();
    if (normalizeForMatch(rowItem) === cleanTarget) {
      foundRow = r + 1;
      break;
    }
  }

  if (foundRow !== -1) {
    sVisual.getRange(foundRow, 5).setValue(directUrl);
    if (commercialName && commercialName !== itemName) {
      sVisual.getRange(foundRow, 3).setValue(commercialName);
    }
    if (specification) {
      sVisual.getRange(foundRow, 4).setValue(specification);
    }
  } else {
    sVisual.appendRow([
      itemName,
      category,
      commercialName,
      specification || "Registrado desde App VIGILARTE",
      directUrl
    ]);
  }

  return createJsonResponse({
    status: "success",
    message: "Foto registrada exitosamente en catálogo",
    url: directUrl,
    item: itemName
  }, 200);
}

// Método 2: Sincronización masiva desde la carpeta de Google Drive
function handleSyncDriveCatalog() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  if (!sVisual) {
    initTechnicalTabs(ss);
    sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  }

  // Asegurar que el catálogo tenga precargadas todas las herramientas y accesorios
  prepopulateCatalogMasterItems(ss);

  let folder;
  const folders = DriveApp.getFoldersByName(CATALOG_DRIVE_FOLDER_NAME);
  if (!folders.hasNext()) {
    folder = DriveApp.createFolder(CATALOG_DRIVE_FOLDER_NAME);
    return createJsonResponse({
      status: "success",
      message: "Carpeta '" + CATALOG_DRIVE_FOLDER_NAME + "' creada en Google Drive. Coloca las fotos con el nombre de cada ítem y vuelve a sincronizar.",
      updatedCount: 0,
      addedCount: 0
    }, 200);
  }
  folder = folders.next();

  const files = folder.getFiles();
  let updatedCount = 0;
  let addedCount = 0;

  // Mapa de filas actuales en CATALOGO_VISUAL
  const data = sVisual.getDataRange().getValues();
  const itemRowMap = new Map();
  for (let r = 1; r < data.length; r++) {
    const rowItem = (data[r][0] || "").toString().trim();
    if (rowItem) {
      itemRowMap.set(normalizeForMatch(rowItem), r + 1);
    }
  }

  while (files.hasNext()) {
    const file = files.next();
    const rawName = file.getName();
    // Quitar extensión: .jpg, .png, .jpeg, .webp
    const baseName = rawName.replace(/\.[a-zA-Z0-9]+$/, "").trim();
    if (!baseName) continue;

    try {
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    } catch (_) {}

    const directUrl = "https://drive.google.com/uc?export=view&id=" + file.getId();
    const normFile = normalizeForMatch(baseName);

    // 1. Coincidencia exacta
    let matchedRow = itemRowMap.get(normFile);

    // 2. Coincidencia difusa (si el nombre del archivo está contenido o contiene el ítem)
    if (!matchedRow) {
      for (const [keyNorm, rowNum] of itemRowMap.entries()) {
        if (normFile.includes(keyNorm) || keyNorm.includes(normFile)) {
          matchedRow = rowNum;
          break;
        }
      }
    }

    if (matchedRow) {
      sVisual.getRange(matchedRow, 5).setValue(directUrl);
      updatedCount++;
    } else {
      // 3. Auto-registro para herramientas/materiales futuros que aún no estaban en la lista
      sVisual.appendRow([
        baseName,
        "General",
        baseName,
        "Sincronizado desde carpeta Drive",
        directUrl
      ]);
      itemRowMap.set(normFile, sVisual.getLastRow());
      addedCount++;
    }
  }

  return createJsonResponse({
    status: "success",
    message: "Sincronización completada: " + updatedCount + " fotos vinculadas, " + addedCount + " nuevos ítems agregados.",
    updatedCount: updatedCount,
    addedCount: addedCount
  }, 200);
}

// Pre-llenar el catálogo con todos los nombres de herramientas y accesorios maestros
function prepopulateCatalogMasterItems(ss) {
  if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
  let sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  if (!sVisual) {
    initTechnicalTabs(ss);
    sVisual = ss.getSheetByName("CATALOGO_VISUAL");
  }

  const currentItems = new Set(
    sVisual.getDataRange().getValues().slice(1).map(r => normalizeForMatch(r[0]))
  );

  let added = 0;

  function collectFromSheet(sheetName, category) {
    const s = ss.getSheetByName(sheetName);
    if (!s) return;
    const data = s.getDataRange().getValues();
    for (let col = 0; col < data[0].length; col++) {
      for (let row = 1; row < data.length; row++) {
        const val = (data[row][col] || "").toString().trim();
        if (val && !currentItems.has(normalizeForMatch(val))) {
          sVisual.appendRow([val, category, val, "Catálogo técnico maestro de obra", ""]);
          currentItems.add(normalizeForMatch(val));
          added++;
        }
      }
    }
  }

  collectFromSheet("HERRAMIENTAS_MATERIAL", "Herramienta");
  collectFromSheet("HERRAMIENTAS_ESTRUCTURA", "Herramienta");
  collectFromSheet("ACCESORIOS_MATERIAL", "Accesorio");

  return added;
}

// Menú interactivo en Google Sheets
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("VIGILARTE")
    .addItem("🔄 Sincronizar Fotos desde Carpeta Drive", "menuSyncDriveCatalog")
    .addItem("📋 Pre-llenar Catálogo con Herramientas y Accesorios", "menuPrepopulateCatalog")
    .addItem("💰 Ver Cotizaciones de Proveedores", "menuShowSupplierQuotes")
    .addItem("⚙️ Inicializar Pestañas Técnicas", "initTechnicalTabs")
    .addToUi();
}

function menuSyncDriveCatalog() {
  const res = handleSyncDriveCatalog();
  const obj = JSON.parse(res.getContent());
  SpreadsheetApp.getUi().alert("VIGILARTE - Sincronización", obj.message, SpreadsheetApp.getUi().ButtonSet.OK);
}

function menuPrepopulateCatalog() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const count = prepopulateCatalogMasterItems(ss);
  SpreadsheetApp.getUi().alert("VIGILARTE - Catálogo", "Se precargaron " + count + " ítems en CATALOGO_VISUAL.", SpreadsheetApp.getUi().ButtonSet.OK);
}

function doGet(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Disparar sincronización desde GET si se solicita
  if (e && e.parameter && e.parameter.action === "sync_drive_catalog") {
    return handleSyncDriveCatalog();
  }

  // Portal Web para Cotizaciones de Múltiples Proveedores
  if (e && e.parameter && e.parameter.action === "cotizar") {
    return handleSupplierQuotationHtml(e);
  }
  if (e && e.parameter && e.parameter.action === "get_supplier_quotes") {
    return handleGetSupplierQuotes(e.parameter.project || "");
  }
  
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
  const catalogoVisual = getCatalogVisualData(ss);

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
    herramientasEstructura: herramientasEstructura,
    catalogoVisual: catalogoVisual
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

// =========================================================================
// PORTAL WEB DE COTIZACIÓN PARA MÚLTIPLES PROVEEDORES
// Permite enviar el mismo enlace a 3, 5 o más proveedores para comparar precios
// =========================================================================

function handleSupplierQuotationHtml(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const project = (e && e.parameter && e.parameter.project) ? decodeURIComponent(e.parameter.project) : "Proyecto General VIGILARTE";
  
  // Obtener ítems de materiales del catálogo visual o parámetros
  let itemsToQuote = [];
  if (e && e.parameter && e.parameter.items) {
    const rawItems = decodeURIComponent(e.parameter.items).split(",");
    itemsToQuote = rawItems.map(name => ({
      name: name.trim(),
      commercialName: name.trim(),
      spec: "Según catálogo de obra",
      unit: "Und",
      qty: 1,
      imageUrl: ""
    }));
  } else {
    // Leer materiales y accesorios del catálogo visual
    const catData = getCatalogVisualData(ss);
    itemsToQuote = catData.filter(i => i.category.toLowerCase().includes("material") || i.category.toLowerCase().includes("accesorio")).map(i => ({
      name: i.itemName,
      commercialName: i.commercialName || i.itemName,
      spec: i.specification || "Conforme a requerimiento de obra",
      unit: i.itemName.toLowerCase().includes("tubo") ? "Tiras (3m)" : (i.itemName.toLowerCase().includes("cable") ? "Caja" : "Und"),
      qty: 10,
      imageUrl: i.imageUrl || ""
    }));
  }

  const scriptUrl = ScriptApp.getService().getUrl();

  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VIGILARTE - Portal de Cotización de Proveedores</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    body { background-color: #0F172A; color: #F8FAFC; padding: 20px; line-height: 1.5; }
    .container { max-width: 860px; margin: 0 auto; background-color: #1E293B; border-radius: 12px; border: 1px solid #334155; padding: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
    .header { border-bottom: 2px solid #0284C7; padding-bottom: 16px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
    .logo-title { display: flex; align-items: center; gap: 12px; }
    .logo-badge { background: linear-gradient(135deg, #0284C7, #10B981); color: white; font-weight: 900; font-size: 18px; padding: 6px 12px; border-radius: 8px; letter-spacing: 1px; }
    .company-title { font-size: 18px; font-weight: bold; color: #F8FAFC; letter-spacing: 1px; }
    .project-card { background-color: #0F172A; border-radius: 8px; border: 1px solid #334155; padding: 14px; margin-bottom: 20px; }
    .project-title { font-size: 14px; color: #38BDF8; font-weight: bold; }
    .form-group { margin-bottom: 14px; }
    label { display: block; font-size: 12px; color: #94A3B8; font-weight: 600; margin-bottom: 6px; }
    input[type="text"], input[type="number"], textarea { width: 100%; background-color: #0F172A; border: 1px solid #334155; border-radius: 6px; padding: 10px; color: #F8FAFC; font-size: 13px; }
    input:focus, textarea:focus { outline: none; border-color: #38BDF8; box-shadow: 0 0 0 2px rgba(56,189,248,0.2); }
    .row { display: flex; gap: 12px; flex-wrap: wrap; }
    .col { flex: 1; min-width: 240px; }
    .table-container { overflow-x: auto; margin-top: 20px; margin-bottom: 20px; }
    table { width: 100%; border-collapse: collapse; text-align: left; }
    th { background-color: #0F172A; color: #38BDF8; font-size: 11px; text-transform: uppercase; padding: 10px; border-bottom: 1px solid #334155; }
    td { padding: 10px; border-bottom: 1px solid #334155; font-size: 12px; vertical-align: middle; }
    .item-name { font-weight: bold; color: #F8FAFC; font-size: 13px; }
    .item-spec { color: #94A3B8; font-size: 11px; margin-top: 2px; }
    .price-input { width: 110px !important; text-align: right; font-weight: bold; color: #4ADE80 !important; }
    .days-input { width: 90px !important; text-align: center; }
    .btn-submit { background: linear-gradient(135deg, #0284C7, #10B981); color: white; border: none; padding: 14px 28px; font-size: 14px; font-weight: bold; border-radius: 8px; cursor: pointer; width: 100%; transition: opacity 0.2s; box-shadow: 0 4px 12px rgba(2,132,199,0.3); }
    .btn-submit:hover { opacity: 0.9; }
    .alert-success { background-color: #064E3B; border: 1px solid #059669; color: #A7F3D0; padding: 16px; border-radius: 8px; text-align: center; display: none; margin-top: 20px; }
    .thumb-img { width: 44px; height: 44px; object-fit: cover; border-radius: 6px; border: 1px solid #334155; background: #0F172A; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-title">
        <div class="logo-badge">V</div>
        <div>
          <div class="company-title">V I G I L A R T E</div>
          <div style="font-size: 11px; color: #94A3B8;">PORTAL DE COTIZACIÓN PARA PROVEEDORES</div>
        </div>
      </div>
      <div style="font-size: 11px; color: #4ADE80; font-weight: bold;">● Solicitud Activa</div>
    </div>

    <div class="project-card">
      <div style="font-size: 11px; color: #94A3B8;">PROYECTO:</div>
      <div class="project-title">${project}</div>
      <div style="font-size: 11px; color: #CBD5E1; margin-top: 4px;">Por favor ingrese sus mejores precios unitarios (en Soles S/.) y tiempo estimado de entrega para los materiales solicitados.</div>
    </div>

    <form id="quoteForm">
      <div class="row">
        <div class="col form-group">
          <label>Nombre de la Ferretería / Razón Social del Proveedor *</label>
          <input type="text" id="supplierName" required placeholder="Ej. Distribuidora Eléctrica Central S.A.C.">
        </div>
        <div class="col form-group">
          <label>RUC / Celular / Contacto *</label>
          <input type="text" id="supplierContact" required placeholder="Ej. 20601234567 / 987654321">
        </div>
      </div>

      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th style="width: 50px;">Foto</th>
              <th>Material / Accesorio & Especificación</th>
              <th style="width: 80px; text-align: center;">Unidad</th>
              <th style="width: 120px; text-align: right;">Precio Unit. S/. *</th>
              <th style="width: 100px; text-align: center;">Entrega (Días)</th>
            </tr>
          </thead>
          <tbody>
            ${itemsToQuote.map((item, idx) => `
              <tr>
                <td>
                  ${item.imageUrl ? `<img src="${item.imageUrl}" class="thumb-img">` : `<div style="width:44px;height:44px;background:#0F172A;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;color:#64748B;">[Foto]</div>`}
                </td>
                <td>
                  <div class="item-name">${item.commercialName}</div>
                  <div class="item-spec">${item.spec}</div>
                  <input type="hidden" class="item-id" value="${item.name}">
                  <input type="hidden" class="item-unit" value="${item.unit}">
                </td>
                <td style="text-align: center; color: #94A3B8;">${item.unit}</td>
                <td style="text-align: right;">
                  <input type="number" step="0.01" min="0" required class="price-input" placeholder="0.00" data-idx="${idx}">
                </td>
                <td style="text-align: center;">
                  <input type="text" class="days-input" placeholder="Inmediato" data-idx="${idx}">
                </td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>

      <div class="form-group">
        <label>Observaciones o Condiciones Adicionales (Opcional)</label>
        <textarea id="notes" rows="2" placeholder="Ej. Precios válidos por 15 días. Incluyen IGV y flete en obra."></textarea>
      </div>

      <button type="submit" class="btn-submit" id="btnSubmit">ENVIAR COTIZACIÓN A VIGILARTE</button>
    </form>

    <div class="alert-success" id="successBox">
      <h3 style="color: #4ADE80; margin-bottom: 6px;">✓ ¡Cotización Recibida Exitosamente!</h3>
      <p style="font-size: 13px;">Muchas gracias por su propuesta. Los precios ingresados se han registrado en nuestro sistema de compras para su evaluación inmediata.</p>
    </div>
  </div>

  <script>
    document.getElementById("quoteForm").addEventListener("submit", function(e) {
      e.preventDefault();
      var btn = document.getElementById("btnSubmit");
      btn.disabled = true;
      btn.innerText = "Enviando cotización...";

      var supplier = document.getElementById("supplierName").value.trim();
      var contact = document.getElementById("supplierContact").value.trim();
      var notes = document.getElementById("notes").value.trim();

      var rows = document.querySelectorAll("tbody tr");
      var quotes = [];
      rows.forEach(function(row) {
        var name = row.querySelector(".item-id").value;
        var unit = row.querySelector(".item-unit").value;
        var price = parseFloat(row.querySelector(".price-input").value) || 0;
        var days = row.querySelector(".days-input").value.trim() || "Inmediato";
        quotes.push({ item: name, unit: unit, price: price, days: days });
      });

      var payload = {
        action: "submit_supplier_quote",
        project: "${project}",
        supplier: supplier,
        contact: contact,
        notes: notes,
        quotes: quotes
      };

      fetch("${scriptUrl}", {
        method: "POST",
        body: JSON.stringify(payload)
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        document.getElementById("quoteForm").style.display = "none";
        document.getElementById("successBox").style.display = "block";
      })
      .catch(function(err) {
        alert("Cotización guardada satisfactoriamente.");
        document.getElementById("quoteForm").style.display = "none";
        document.getElementById("successBox").style.display = "block";
      });
    });
  </script>
</body>
</html>`;

  return HtmlService.createHtmlOutput(html)
    .setTitle("VIGILARTE - Portal de Cotización de Proveedores")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function handleSubmitSupplierQuote(payload) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const SHEET_NAME = "COTIZACIONES_PROVEEDORES";
  let sheet = ss.getSheetByName(SHEET_NAME);

  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    const headers = [
      "FECHA_HORA", "PROYECTO", "PROVEEDOR", "CONTACTO_RUC",
      "ITEM", "UNIDAD", "PRECIO_UNIT_SOLES", "PLAZO_ENTREGA", "OBSERVACIONES"
    ];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setBackground("#0369A1").setFontColor("#FFFFFF").setFontWeight("bold");
    sheet.setFrozenRows(1);
  }

  const time = Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");
  const project = payload.project || "General";
  const supplier = payload.supplier || "Proveedor Anónimo";
  const contact = payload.contact || "N/A";
  const notes = payload.notes || "";
  const quotes = payload.quotes || [];

  quotes.forEach(q => {
    sheet.appendRow([
      time,
      project,
      supplier,
      contact,
      q.item,
      q.unit,
      q.price,
      q.days,
      notes
    ]);
  });

  return createJsonResponse({ status: "success", message: "Cotización registrada para " + quotes.length + " ítems.", count: quotes.length }, 200);
}

function handleGetSupplierQuotes(projectName) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName("COTIZACIONES_PROVEEDORES");
  if (!sheet) {
    return createJsonResponse({ quotes: [], minPrices: {} }, 200);
  }

  const rows = sheet.getDataRange().getValues();
  if (rows.length <= 1) {
    return createJsonResponse({ quotes: [], minPrices: {} }, 200);
  }

  const quotes = [];
  const minPrices = {};

  for (let i = 1; i < rows.length; i++) {
    const r = rows[i];
    const rowProj = r[1] ? r[1].toString().trim() : "";
    if (projectName && rowProj && !rowProj.toLowerCase().includes(projectName.toLowerCase())) {
      continue;
    }

    const item = r[4] ? r[4].toString().trim() : "";
    const price = parseFloat(r[6]) || 0;
    const supplier = r[2] ? r[2].toString().trim() : "";

    quotes.push({
      date: r[0],
      project: rowProj,
      supplier: supplier,
      contact: r[3],
      item: item,
      unit: r[5],
      price: price,
      deliveryDays: r[7],
      notes: r[8]
    });

    if (price > 0) {
      if (!minPrices[item] || price < minPrices[item].price) {
        minPrices[item] = { price: price, supplier: supplier };
      }
    }
  }

  return createJsonResponse({ quotes: quotes, minPrices: minPrices, total: quotes.length }, 200);
}

function menuShowSupplierQuotes() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName("COTIZACIONES_PROVEEDORES");
  if (!sheet || sheet.getLastRow() <= 1) {
    SpreadsheetApp.getUi().alert("VIGILARTE - Cotizaciones", "Aún no se han recibido cotizaciones de proveedores.", SpreadsheetApp.getUi().ButtonSet.OK);
    return;
  }
  const total = sheet.getLastRow() - 1;
  SpreadsheetApp.getUi().alert("VIGILARTE - Cotizaciones", "Se han registrado " + total + " cotizaciones en la pestaña COTIZACIONES_PROVEEDORES.", SpreadsheetApp.getUi().ButtonSet.OK);
}

