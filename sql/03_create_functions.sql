-- 03_create_functions.sql
-- Скрипт для создания хранимых функций и процедур

BEGIN;

-- Функция для создания списания ПРОДУКТА (оставляем как было)
CREATE OR REPLACE FUNCTION создать_списание_продукта (
    p_id_склада INTEGER,
    p_id_сотрудника_ответственного INTEGER,
    p_id_причины_списания INTEGER,
    p_комментарий TEXT,
    p_id_продукта INTEGER,
    p_количество NUMERIC
)
RETURNS INTEGER -- Возвращаем ID созданного списания (из родительской таблицы "Списание")
AS $$
DECLARE
    inserted_sписание_id INTEGER;
BEGIN
    INSERT INTO "Списание" (
        "ID_склада", "ID_сотрудника_ответственного", "ID_причины_списания", "Комментарий", "Дата_списания"
    ) VALUES (
        p_id_склада, p_id_сотрудника_ответственного, p_id_причины_списания, p_комментарий, CURRENT_TIMESTAMP
    ) RETURNING "ID_списания" INTO inserted_sписание_id;

    INSERT INTO "СписаниеПродуктов" (
        "ID_списания",
        "ID_склада", "ID_сотрудника_ответственного", "ID_причины_списания", "Комментарий", "Дата_списания",
        "ID_продукта", "Количество"
    ) VALUES (
        inserted_sписание_id,
        p_id_склада, p_id_сотрудника_ответственного, p_id_причины_списания, p_комментарий, (SELECT "Дата_списания" FROM "Списание" WHERE "ID_списания" = inserted_sписание_id),
        p_id_продукта, p_количество
    );
    RETURN inserted_sписание_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Ошибка в функции создать_списание_продукта: % (%)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$ LANGUAGE plpgsql;


-- Функция для создания списания БЛЮДА (оставляем как было)
CREATE OR REPLACE FUNCTION создать_списание_блюда (
    p_id_склада INTEGER,
    p_id_сотрудника_ответственного INTEGER,
    p_id_причины_списания INTEGER,
    p_комментарий TEXT,
    p_id_блюда INTEGER,
    p_количество INTEGER
)
RETURNS INTEGER -- Возвращаем ID созданного списания
AS $$
DECLARE
    inserted_sписание_id INTEGER;
BEGIN
    INSERT INTO "Списание" (
        "ID_склада", "ID_сотрудника_ответственного", "ID_причины_списания", "Комментарий", "Дата_списания"
    ) VALUES (
        p_id_склада, p_id_сотрудника_ответственного, p_id_причины_списания, p_комментарий, CURRENT_TIMESTAMP
    ) RETURNING "ID_списания" INTO inserted_sписание_id;

    INSERT INTO "СписаниеБлюд" (
        "ID_списания",
        "ID_склада", "ID_сотрудника_ответственного", "ID_причины_списания", "Комментарий", "Дата_списания",
        "ID_блюда", "Количество"
    ) VALUES (
        inserted_sписание_id,
        p_id_склада, p_id_сотрудника_ответственного, p_id_причины_списания, p_комментарий, (SELECT "Дата_списания" FROM "Списание" WHERE "ID_списания" = inserted_sписание_id),
        p_id_блюда, p_количество
    );
    RETURN inserted_sписание_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Ошибка в функции создать_списание_блюда: % (%)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$ LANGUAGE plpgsql;


-- НОВАЯ ФУНКЦИЯ: Рассчитать среднюю цену закупки продукта
CREATE OR REPLACE FUNCTION "РассчитатьСреднююЦенуЗакупки"(id_продукта_вход INTEGER)
RETURNS NUMERIC AS $$
    SELECT AVG("Цена_закупки") FROM "ПозицияПоступления" WHERE "ID_продукта" = id_продукта_вход;
$$ LANGUAGE sql; -- Для чистого SQL не нужен BEGIN/END, если одно выражение


-- НОВАЯ ПРОЦЕДУРА: Создать новый заказ
CREATE OR REPLACE FUNCTION "СоздатьНовыйЗаказ"(
    id_кассы_вход INTEGER,
    id_сотрудника_вход INTEGER,
    OUT id_нового_заказа_выход INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "Заказ"("ID_кассы", "ID_сотрудника_оформившего")
    VALUES (id_кассы_вход, id_сотрудника_вход)
    RETURNING "ID_заказа" INTO id_нового_заказа_выход;
END;
$$;


-- НОВАЯ ПРОЦЕДУРА: Добавить позицию в заказ и обновить общую сумму заказа
CREATE OR REPLACE FUNCTION "ДобавитьПозициюВЗаказ"(
    id_заказа_вход INTEGER,
    id_блюда_вход INTEGER,
    количество_вход INTEGER
)
RETURNS VOID -- Процедура не возвращает значение напрямую, она модифицирует данные
LANGUAGE plpgsql AS $$
DECLARE
    цена_блюда_текущая NUMERIC;
BEGIN
    -- Получаем текущую цену блюда
    SELECT "Цена_продажи" INTO цена_блюда_текущая
    FROM "Блюдо"
    WHERE "ID_блюда" = id_блюда_вход;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Блюдо с ID % не найдено.', id_блюда_вход;
    END IF;

    -- Добавляем позицию в заказ
    -- Используем ON CONFLICT для случая, если такая позиция уже есть (например, увеличиваем количество)
    INSERT INTO "ПозицияЗаказа"("ID_заказа", "ID_блюда", "Количество", "Цена_на_момент_заказа")
    VALUES (id_заказа_вход, id_блюда_вход, количество_вход, цена_блюда_текущая)
    ON CONFLICT ("ID_заказа", "ID_блюда") DO UPDATE SET
        "Количество" = "ПозицияЗаказа"."Количество" + excluded."Количество",
        "Цена_на_момент_заказа" = excluded."Цена_на_момент_заказа"; -- Обновляем цену, если она могла измениться

    -- Обновляем общую сумму заказа
    UPDATE "Заказ"
    SET "Общая_сумма" = (
        SELECT COALESCE(SUM("Количество" * "Цена_на_момент_заказа"), 0)
        FROM "ПозицияЗаказа"
        WHERE "ID_заказа" = id_заказа_вход
    )
    WHERE "ID_заказа" = id_заказа_вход;
END;
$$;

COMMIT;