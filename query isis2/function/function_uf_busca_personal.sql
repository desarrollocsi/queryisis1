CREATE OR REPLACE FUNCTION public.uf_busca_personal(apellidopat character varying, apellidomat character varying, nombre character varying)
 RETURNS TABLE(p_fila character varying)
 LANGUAGE plpgsql
AS $function$

DECLARE reg1 RECORD;
DECLARE vNombre varchar(250) := CASE WHEN (apellidopat<>'' AND apellidomat='' AND nombre='') THEN apellidopat
                                     WHEN (apellidopat<>'' AND apellidomat<>'' AND nombre='') THEN apellidopat||' '||apellidomat
                                     WHEN (apellidopat<>'' AND apellidomat<>'' AND nombre<>'') THEN apellidopat||' '||apellidomat||' '||nombre
                                END;

BEGIN
	--recorro cursor de productos
	FOR reg1 IN 
		SELECT 
			substring(cc_descco from 1 for (CASE WHEN position('-' in cc_descco)>0 THEN position('-' in cc_descco)-2 ELSE char_length(cc_descco) END)) AS nombre,
			cc_dni AS dni,
			cc_estcco AS estado
		FROM centros_de_costo 
		WHERE cc_descco LIKE ''||vNombre||'%'
	LOOP
	--raise notice 'Value vNombre: %', vNombre;
		p_fila := reg1.nombre||'|'||reg1.dni||'|'||reg1.estado;
		return next;
	END LOOP;
	RETURN;
END;
$function$
;
