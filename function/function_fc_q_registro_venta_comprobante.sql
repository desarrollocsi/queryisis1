CREATE OR REPLACE FUNCTION public.fc_q_registro_venta_comprobante(p_fecha1 character, p_fecha2 character)
 RETURNS SETOF tpy_registro_venta_comprobante
 LANGUAGE plpgsql
AS $function$
/*
	Nombre Función	:	fc_q_registro_venta_comprobante
							donde.-
								fc:facturacion, lg:logistica, fr:farmacia, ug: uso global, etc.
								i:insert, u:pdate, d:elete, q:query
	Creador			:	JLKB
	Creación		:	18/05/2021 --Tipos de Doc. Identidad, se agrego LOTE
	Objetivo		:	registro de ventas - comprobantes del servicio ambulatorio
	Motivo			:
*/
DECLARE data tpy_registro_venta_comprobante;
DECLARE d_fecha1  date;
DECLARE d_fecha2  date;
BEGIN
  d_fecha1 := to_date(p_fecha1, 'YYYY-MM-DD'); 
  d_fecha2 := to_date(p_fecha2, 'YYYY-MM-DD'); 
  for data in 	
    SELECT pwtgn00.nprfctra,pwtgn00.tcmprbnte,pwtgn00.nscmprbnte,pwtgn00.ncmprbnte,to_char(pwtgn00.femsn,'dd/mm/yyyy'), 
    case pwtgn00.ctdcmnto when 0 then 'SD' when 1 then 'DNI' when 2 then 'CE' when 3 then 'RUC' when 4 then 'CIP' when 5 then 'PAS' when 7 then 'TUTOR' when 8 then 'RUC' end tip_doc,
    --sgatv01.catdcmnto as tip_doc,
    coalesce(pwtgn00.ndidntdd,'') as nro_doc, 
    --trim(pwtgn00.rsaynmbrs) as nom_cliente,
    replace(replace(replace(replace(replace(replace(pwtgn00.rsaynmbrs,'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U'),'?','Ñ')  AS nom_cliente,
    --(select case when count(*) > 0 then 'CONSULTA AMBULATORIA' else 'CONSUMO' end from pwccp01 where pwccp01.nprfctra = pwtgn00.nprfctra and pwccp01.cprcdmnto = 29) as cons_amb,
    case when a.nprfctra is not null then 'CONSULTA AMBULATORIA' else 'CONSUMO' end as cons_amb,
    pwtgn00.cmnda, pwtgn00.vvnta, pwtgn00.migv, pwtgn00.imprdndo, pwtgn00.tcta,
    case when pwtgn00.scpgo = 'N' then 'VIGENTE' when pwtgn00.scpgo = 'A' then 'ANULADO' end as estado,
    case when pwtgn00.tcmprbnte = 'N' then (SELECT doc_refer.tcmprbnte FROM pwtgn00 doc_refer WHERE pwtgn00.corcmprbnte = doc_refer.crcmprbnte) end as ref_tipo,
    case when pwtgn00.tcmprbnte = 'N' then (SELECT doc_refer.nscmprbnte FROM pwtgn00 doc_refer WHERE pwtgn00.corcmprbnte = doc_refer.crcmprbnte) end as ref_serie,
    case when pwtgn00.tcmprbnte = 'N' then (SELECT doc_refer.ncmprbnte FROM pwtgn00 doc_refer WHERE pwtgn00.corcmprbnte = doc_refer.crcmprbnte) end as ref_numero,
    case when pwtgn00.tcmprbnte = 'N' then (SELECT to_char(doc_refer.femsn,'dd/mm/yyyy') FROM pwtgn00 doc_refer WHERE pwtgn00.corcmprbnte = doc_refer.crcmprbnte) end as ref_fecha,
    'C' as frm_pago, pwtgn00.ccja,pwtgn00.fecha_envio,pwtgn00.fecha_devolucion,
	coalesce(pwtgn00.lote,0) lote
    FROM pwtgn00 inner join sgatv01 on(pwtgn00.ctdcmnto = sgatv01.ctdcmnto)
    LEFT JOIN ( select DISTINCT pwccp01.nprfctra
    from pwccp01
    where pwccp01.cprcdmnto = 29 --CONSULTA AMBULATORIA
      ) a ON(
    a.nprfctra = pwtgn00.nprfctra)
    WHERE  cast(pwtgn00.femsn as date) between d_fecha1 and d_fecha2 
    and pwtgn00.nscmprbnte > 0
	AND pwtgn00.ncmprbnte > 0
    order by 2,3,4
loop
  return next data;
  end loop;
END;
$function$
;
