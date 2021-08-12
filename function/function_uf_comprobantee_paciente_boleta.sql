CREATE OR REPLACE FUNCTION public.uf_comprobantee_paciente_boleta(an_crcmprbnte numeric)
 RETURNS text
 LANGUAGE plpgsql
AS $function$

DECLARE totalPago pwccj06.mpgdo%TYPE;
DECLARE vuelto pwccj06.vlto%TYPE;
DECLARE usuario pwccj06.cucrgstro%TYPE;
DECLARE caja pwccj06.ccja%TYPE;
DECLARE prefactura pwccj06.nprfctra%TYPE;
DECLARE esTituloGratuito BOOLEAN;
DECLARE cabeceraComprobante TEXT;
DECLARE detalleComprobante TEXT;
DECLARE trama TEXT;
DECLARE mediosDePagos TEXT;
DECLARE GLOSA_GENERAL TEXT;
DECLARE GLOSA_TITULO_GRATUITO TEXT;
DECLARE RUTA_SERVIDOR_IMPRESION TEXT;
DECLARE NOMBRE_IMPRESORA TEXT;
DECLARE COMANDO TEXT;


BEGIN

GLOSA_GENERAL := '-El paciente cuenta con 15 dias para la prestación del servicio.^-El COPAGO no es reembolsable.^-No se aceptan cambios/devoluciones en productos de farmacia por requerir condiciones especiales de almacenamiento.^-Toda devolución se efectuará con transferencia bancaria, en un plazo no mayor a 7 dias.';
GLOSA_TITULO_GRATUITO :='TRANSFERENCIA GRATUITA DE UN BIEN Y/O SERVICIO PRESTADO GRATUITAMENTE';
RUTA_SERVIDOR_IMPRESION := 'clinicasantaisabel.com:aceptauser:C$Iacepta:\\SIF2.clinicasantaisabel.com';

/*QUERY PARA OBTENER VUELTO Y TOTAL DE CPE*/
SELECT SUM(pwccj06.mpgdo) AS mpsls,
   	        SUM(pwccj06.vlto) AS vlto,
	        MAX(ccja) AS caja,
   	        MAX(cucrgstro) AS usuario
INTO totalPago, vuelto,caja,usuario
FROM pwccj06
WHERE crcmprbnte = an_crcmprbnte;

/*QUERY PARA OBTENER NOMBRE DE LA IMPRESORA Y COMANDO*/
WITH impresora AS (
	SELECT SUBSTRING(TRIM(a.nimprsra),7) AS nombreDeImpresora,
			TRIM(SUBSTRING(a.dgnrca,0,STRPOS(a.dgnrca,'-'))) = 'MARKETING' AS esMarketing
	FROM pwcsu10 a
	JOIN pwccj11 b ON (a.ncpemsn = b.ncpemsn AND b.ccja NOT IN(9) AND a.cprcso=2 AND a.csbprcso=2)
	JOIN pwccj01 c ON (b.ccja = c.ccja)
	WHERE  c.cusga = usuario
	AND b.ccja = caja
)SELECT RUTA_SERVIDOR_IMPRESION||nombreDeImpresora,
		 COALESCE(CASE WHEN esMarketing THEN 'emitir_isis2' END,'emitir_ticket')
INTO NOMBRE_IMPRESORA,COMANDO
FROM impresora;



/*QUERY PARA OBTENER LOS MEDIOS DE PAGOS DEL CPE*/
	SELECT STRING_AGG(
		CASE 
		WHEN a.cmnda = 1 THEN
			CASE 
			WHEN a.tfpgo = 'EF' THEN 'Efectivo' 
			WHEN a.tfpgo = 'TJ' THEN 
				CASE
				WHEN a.ttrjta = 'D' THEN  'T.Deb. '||b.drsmda||' '||LPAD(a.ntrjta,10,'*')
				WHEN a.ttrjta = 'C' THEN  'T.Cre. '||b.drsmda||' '||LPAD(a.ntrjta,10,'*')
				END
			WHEN a.tfpgo = 'NC' THEN 'N/C'||' Nº'||
				CASE WHEN a.crcmprbntencrdto IS NULL THEN '' ELSE fpwtgnd01(a.crcmprbntencrdto,False) END
			END 
		WHEN a.cmnda = 2 THEN	
			'Dólares USD ' || TRUNC(a.mpdlrs,2)
		END ||'|'||
		a.mpgdo::TEXT||'}', '' order by a.nitm) as pagos_realizados ,MAX(a.nprfctra)
	FROM pwccj06 a
	INTO mediosDePagos,prefactura
	LEFT JOIN pwctv37 b ON(a.cmtrjta = b.cmtrjta)
	INNER JOIN pwetv02 c ON( a.cmnda = c.cmnda)
	WHERE crcmprbnte  = an_crcmprbnte; 

/*QUERY OBTIENE SI TIPO DE VENTA ES TITULO GRATUITO*/
SELECT tvnta='T'
INTO esTituloGratuito
FROM pwccp00
WHERE nprfctra = prefactura;
	 
WITH cpeCabecera AS (
SELECT 
		CONCAT_WS('|',
			'docid='||a.tcmprbnte||LPAD(a.nscmprbnte::TEXT,3,'0')||'-'||LPAD(a.ncmprbnte::TEXT,8,'0')||'&comando='||COMANDO||'&parametros=&datos='||
			'03'/*AS tipoDocumento*/,
			a.tcmprbnte||LPAD(a.nscmprbnte::TEXT,3,'0')||'-'||LPAD(a.ncmprbnte::TEXT,8,'0') /*AS numeroCpe*/,
			TO_CHAR(a.femsn ,'YYYY-MM-DD')/* AS fechaDeEmision*/,
			'PEN||||||||0101||}'
		) AS cabeceraDelComprobante,
		'20100375061|6|CLINICA SANTA ISABEL S.A.C.|CLINICA SANTA ISABEL S.A.C.|150130|AV. GUARDIA CIVIL 135|URB. CORPAC|LIMA|LIMA|SAN BORJA|PE||||0000}' AS datosDelEmisor,
		CONCAT_WS('|',
			COALESCE(CASE WHEN a.ctdcmnto =7 THEN '99999999' END,COALESCE(a.ndidntdd, '99999999')) /*AS numeroDocumentoReceptor*/,
			case a.ctdcmnto 
				when 0 then '0'
				when 1 then '1'
				when 2 then '4'
				when 8 then '6'
				when 3 then '7' --7
				when 5 then '7' --se agrego linea provisional pasaporte
				when 7 then '0'
			END /*AS TipoDocumentoReceptor*/,
			a.rsaynmbrs /*AS razonSocial*/,
			'||',
			a.drccn /*AS direccionCompleta*/,
			'||||0000}~'
		) AS datosDelReceptor,
		
		CASE
		WHEN COUNT(*)FILTER(WHERE c.caigv='I') > 0 THEN  --TOTAL VALOR DE VENTA - EXPORTACIÓN / EXONERADAS / INAFECTAS
			SUM(c.vvnta)FILTER(WHERE c.caigv='I')::TEXT||'|0.00|O|9998|INA|FRE}'
		ELSE
			'|||||}'
		END||
		CASE
		WHEN COUNT(*)FILTER(WHERE b.tvnta='T' OR c.caigv='T') > 0 THEN --TOTAL VALOR DE VENTA - GRATUITAS
			SUM(c.vvnta)FILTER(WHERE b.tvnta='T' OR c.caigv='T')::TEXT||'|0.00|Z|9996|GRA|FRE}'
		ELSE
			'|||||}'
		END||
		CASE
		WHEN COUNT(*)FILTER(WHERE c.caigv='A') > 0 THEN --TOTAL VALOR DE VENTA - GRAVADAS
			SUM(c.vvnta)FILTER(WHERE c.caigv='A')::TEXT||'|'||ROUND(SUM(c.migv),2)||'|S|1000|IGV|VAT}'
		ELSE
			'|||||}'
		END
		||'|||||}~' AS impuestosTotalesPorOperacion,
		CONCAT_WS('|',MAX(a.vvnta),MAX(a.tcta),'','','',MAX(a.tcta),'',MAX(a.migv)||'}~')AS montosTotales,
		'||||}~'  AS descuentoGlobal,
		'|||||}~' AS datosDelAnticipo,
		'[D]~' AS detalles,
		'|}~' AS leyendas,

		CONCAT_WS('|',
			'|||417 4100|'||MAX(f.cacja),
			MAX(f.ccja) /*AS caja*/,
			TO_CHAR(a.femsn,'HH24:MI') /*AS hora*/,
			COALESCE(c_codificacion_hexadecimal(MAX(d.aynttlr)),''),
			COALESCE(c_codificacion_hexadecimal(MAX(d.deafldo)),''),
			COALESCE(c_codificacion_hexadecimal(MAX(e.rsabrvda)),''),
			MAX(TRIM(a.cucrgstro)),
			a.nprfctra /*AS prefactura*/,
			a.cayccja  /*AS NroAperturaCaja*/,
			a.crcmprbnte /*AS idComprobante*/,
			COALESCE(CASE WHEN esTituloGratuito THEN 0.00 END,totalPago) /*total pago*/	,			  
			TRUNC(vuelto,2),
			a.imprdndo /*AS redondeo*/,
			'||',
			c_codificacion_hexadecimal(fpwcgnd02(MAX(b.cpcnte))),/*paciente*/
			'',
			COALESCE(CASE WHEN esTituloGratuito THEN GLOSA_TITULO_GRATUITO END,c_codificacion_hexadecimal(GLOSA_GENERAL))/*GLOSA*/,				  
			a.pigv /*AS igv*/,
			COALESCE(CASE WHEN esTituloGratuito THEN 0.00 END, a.sttl)/*AS totalSinRedondeo*/,
			COALESCE(CASE WHEN MAX(b.tvnta)='I' THEN '1'END,'0'),
			COALESCE(CASE WHEN MAX(g.dtip) = 'TUTOR' THEN 'SD' END,MAX(g.dtip)),
			'||}'
		) AS adjuntos,
		
		CONCAT_WS('|',
			'',		  
			f_nro_a_letras(COALESCE(CASE WHEN esTituloGratuito THEN 0.00 END,a.tcta))||' SOLES',
			'',
			COALESCE(NOMBRE_IMPRESORA,''),
			COALESCE(CASE WHEN NOMBRE_IMPRESORA IS NOT NULL THEN '2' END,''),	  
			COALESCE(COMANDO,'emitir_ticket')
		) as impresion,	
		'[MP]~|}~\' AS mediosDePago
FROM pwtgn00 a
JOIN pwccp00 b ON (a.clcl=b.clcl AND a.cemprsa=b.cemprsa AND a.nprfctra=b.nprfctra AND a.cpcnte=b.cpcnte)
JOIN pwtgn01 c ON (a.crcmprbnte=c.crcmprbnte)
LEFT JOIN pwcad00 d ON (a.clcl=d.clcl AND a.cemprsa=d.cemprsa AND a.nprfctra=d.nprfctra)
LEFT JOIN pwces00 e on(b.cesgrs=e.cesgrs)
JOIN pwccj00 f ON (a.clcl=f.clcl AND a.cemprsa=f.cemprsa AND a.ccja=f.ccja)
JOIN sgatv01 g on (a.ctdcmnto=g.ctdcmnto)
WHERE a.crcmprbnte=an_crcmprbnte
AND a.scpgo = 'N'
AND a.nscmprbnte > 0
AND c.vvnta > 0
GROUP BY a.crcmprbnte
)SELECT   CONCAT(cabeceraDelComprobante,
				 datosDelEmisor,
				 datosDelReceptor,
				 impuestosTotalesPorOperacion,
				 montosTotales,
				 descuentoGlobal,
				 datosDelAnticipo,
				 detalles,
				 leyendas,
				 adjuntos,
				 impresion,
				 mediosDePago)
INTO cabeceraComprobante
FROM cpeCabecera;



WITH cpeDetalle AS (
SELECT 
		(ROW_NUMBER() OVER  (PARTITION BY ''))::TEXT ||'|'||
		TRUNC(b.cntdd,2)::TEXT||'|'||
		'NIU|'||
		CASE 
		WHEN b.caigv='T' OR c.tvnta='T' THEN b.pidscnto::TEXT||'|0.00|'||b.pidscnto::TEXT||'|02|'
		WHEN b.caigv='I' THEN b.vvnta::TEXT||'|'||ROUND(b.migv,2)::TEXT||'|'||ROUND(b.vvnta/b.cntdd,2)::TEXT||'|01|'
		WHEN b.caigv='A' THEN ROUND(b.vvnta,2)||'|'||ROUND(b.migv,2)||'|'||ROUND((b.vvnta + b.migv)/b.cntdd,2)||'|01|'
		END||	
		CASE
		WHEN c.tvnta='I' AND b.csgro > 0 AND  d.id_tabla IS NULL THEN  
			'false|00|'||ROUND(b.csgro/100,2)||'|'||ROUND(b.pidscnto * b.csgro/100,2)||'|'||ROUND(b.pudscnto *  b.cntdd, 2)||'|'
		ELSE 
			'|||||'
		END||
		CASE 
		WHEN b.caigv='T' OR c.tvnta='T' THEN b.pidscnto::TEXT||'|'||'0.00|Z|0.00|21|9996|GRA|FRE|'
		WHEN b.caigv='I' THEN b.vvnta::TEXT||'|'||ROUND(b.migv,2)||'|O|0.00|30|9998|INA|FRE|'
		WHEN b.caigv='A' THEN b.vvnta::TEXT||'|'||ROUND(b.migv,2)||'|S|18.00|10|1000|IGV|VAT|'
		END||
		'|||||||||||||||'||
		c_codificacion_hexadecimal(fpwcpcd03(b.tdcmprbnte, b.cprcdmnto))||'|'||
		CASE 
		WHEN d.id_tabla IS NOT NULL THEN  --CFIJO		 		
		   '(COPAGO FIJO )'  	 
		 ELSE
			CASE WHEN b.csgro > 0 THEN   --CVARIABLE
			'(COPAGO VARIABLE: '||CAST(TRUNC(b.csgro) AS VARCHAR) || '%)'
			ELSE
			''
			END
		 END ||'|'|| --DESCRIPCIÓN ADICIONAL
		LPAD(b.TDCMPRBNTE::TEXT,2,'0')||b.CPRCDMNTO::TEXT||'|'||
		COALESCE(uf_codigo_sunat(b.tdcmprbnte,b.cprcdmnto,a.nprfctra),'')||'|'||
		'|'||
		CASE 
		WHEN c.tvnta='T' OR b.caigv='T' THEN '0.00|'		
		WHEN d.id_tabla is not NULL  AND b.cntdd = 1 THEN b.vvnta::TEXT||'|'
		WHEN d.id_tabla is not NULL AND b.cntdd > 1 THEN b.pudscnto::TEXT||'|'
		ELSE
			 b.pudscnto::TEXT||'|'
		END||
		'|||||}' AS tramaDetalle
FROM pwtgn00 a
JOIN pwtgn01 b ON (a.crcmprbnte=b.crcmprbnte)
JOIN pwccp00 c ON (a.clcl=c.clcl AND a.cemprsa=c.cemprsa AND a.nprfctra=c.nprfctra)
LEFT JOIN tabla_maestra d on(d.id_tabla in(6,10) /*COPAGOS FIJOS*/
AND b.cprcdmnto  = d.id_texto::NUMERIC
AND b.tdcmprbnte = 1    /*SERVICIOS*/ )  	  
WHERE a.crcmprbnte=an_crcmprbnte
AND b.vvnta > 0
)SELECT STRING_AGG(cpeDetalle.tramaDetalle, '' ORDER BY 1)
INTO detalleComprobante
FROM cpeDetalle;

trama := REPLACE(cabeceraComprobante,'[D]', detalleComprobante);
trama := REPLACE(trama,'[MP]', COALESCE(CASE WHEN esTituloGratuito THEN '|}' END,mediosDePagos));

RETURN trama;
END;
$function$
;
