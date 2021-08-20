CREATE OR REPLACE FUNCTION c_generacion_numero_lote_tedef(codigoDeIafa INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $function$

DECLARE numeroDeLote INTEGER;

BEGIN
			
	WITH generaNumeroDeLote AS (
		SELECT 
				cesgrs::TEXT ~ '30' AS esNoConsiderado,
				cesgrs AS codigoDeIafa,
				(COALESCE(CASE WHEN lote = 0 OR  substr(lote::TEXT,2) LIKE '' THEN 0 END,
				substr(lote::TEXT,2)::INT) + 1)::TEXT AS numeroCorrelativo
		FROM pwccp04 
		WHERE cesgrs=codigoDeIafa
		ORDER BY fcrgstro DESC LIMIT 1
	)SELECT (COALESCE(CASE WHEN esNoConsiderado THEN '' END,a.codigoDeIafa::TEXT)||LPAD(numeroCorrelativo,5,'0'))::INT
	INTO numeroDeLote
	FROM generaNumeroDeLote as a;
	
	
	RETURN numeroDeLote;
	
END ; 
$function$;
