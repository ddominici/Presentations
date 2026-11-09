-- Logica di dominio nel database + LISTEN/NOTIFY.
SET search_path = shop, public;

-- Transizioni di stato ammesse
CREATE FUNCTION check_status_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path = shop, public AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT (
            (OLD.status = 'new'       AND NEW.status IN ('confirmed', 'cancelled')) OR
            (OLD.status = 'confirmed' AND NEW.status IN ('paid', 'cancelled'))      OR
            (OLD.status = 'paid'      AND NEW.status IN ('shipped', 'cancelled'))   OR
            (OLD.status = 'shipped'   AND NEW.status = 'delivered')
        ) THEN
            RAISE EXCEPTION 'Transizione di stato non ammessa: % -> %', OLD.status, NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END $$;

CREATE TRIGGER orders_status_transition
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION check_status_transition();

-- Totale ordine ricalcolato dalle righe. SECURITY DEFINER: il totale deve restare
-- coerente a prescindere dalle policy del chiamante (la funzione non è invocabile direttamente).
CREATE FUNCTION refresh_order_total() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = shop, public AS $$
DECLARE
    v_order bigint := COALESCE(NEW.order_id, OLD.order_id);
BEGIN
    UPDATE orders o
       SET total = COALESCE((SELECT sum(i.quantity * i.unit_price) FROM order_items i WHERE i.order_id = v_order), 0)
     WHERE o.id = v_order;
    RETURN NULL;
END $$;

CREATE TRIGGER order_items_total
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW EXECUTE FUNCTION refresh_order_total();

-- Evento ordine: la tabella conserva il fatto, pg_notify lo segnala.
-- Payload piccolo (chiave + stato), ben sotto il limite di 8000 byte: i dati si rileggono via API.
-- Le notifiche sono consegnate dopo il commit; con rollback vengono scartate.
CREATE FUNCTION notify_order_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = shop, public AS $$
DECLARE
    v_type text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_type := 'created';
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        v_type := 'status_changed';
    ELSE
        RETURN NEW;
    END IF;

    INSERT INTO order_events (order_id, region, event_type, old_status, new_status)
    VALUES (NEW.id, NEW.region, v_type,
            CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END, NEW.status);

    PERFORM pg_notify('order_events', json_build_object(
        'order_id',     NEW.id,
        'order_number', NEW.order_number,
        'event',        v_type,
        'old_status',   CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END,
        'status',       NEW.status,
        'region',       NEW.region,
        'by',           session_user
    )::text);
    RETURN NEW;
END $$;

CREATE TRIGGER orders_notify
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION notify_order_change();

REVOKE EXECUTE ON FUNCTION refresh_order_total(), notify_order_change() FROM PUBLIC;
