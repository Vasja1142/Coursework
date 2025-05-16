-- 08_create_roles_and_permissions.sql
-- ВАЖНО: Выполнять под суперпользователем (например, postgres)!
-- Этот скрипт может потребовать ДВУХ запусков.
-- Первый запуск очистит максимум зависимостей и удалит роли.
-- Второй запуск создаст новые роли и выдаст права.

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- ЭТАП 1: ОЧИСТКА И УДАЛЕНИЕ СТАРЫХ РОЛЕЙ (ЗАПУСТИТЬ ПЕРВЫМ)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DO $$
DECLARE
  role_name_quoted TEXT;
  role_name_lower TEXT;
  roles_to_clean_quoted TEXT[] := ARRAY['"Владелец"', '"АдминистраторСклада"', '"Работник"'];
  roles_to_clean_lower TEXT[] := ARRAY['владелец', 'администраторсклада', 'работник'];
BEGIN
  RAISE NOTICE '--- STARTING CLEANUP PHASE ---';

  -- Очистка ролей, созданных В КАВЫЧКАХ
  FOREACH role_name_quoted IN ARRAY roles_to_clean_quoted
  LOOP
    -- Используем trim для получения чистого имени для проверки в pg_roles
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = trim(BOTH '"' FROM role_name_quoted)) THEN
      RAISE NOTICE 'Cleaning up quoted role: %', role_name_quoted;
      EXECUTE 'REASSIGN OWNED BY ' || role_name_quoted || ' TO postgres;';
      EXECUTE 'DROP OWNED BY ' || role_name_quoted || ';';
      EXECUTE 'DROP ROLE IF EXISTS ' || role_name_quoted || ';';
    ELSE
      RAISE NOTICE 'Quoted role % does not exist, skipping.', role_name_quoted;
    END IF;
  END LOOP;

  -- Очистка ролей, созданных БЕЗ КАВЫЧЕК (в нижнем регистре)
  FOREACH role_name_lower IN ARRAY roles_to_clean_lower
  LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name_lower) THEN
      RAISE NOTICE 'Cleaning up lower-case role: %', role_name_lower;
      EXECUTE 'REASSIGN OWNED BY ' || quote_ident(role_name_lower) || ' TO postgres;';
      EXECUTE 'DROP OWNED BY ' || quote_ident(role_name_lower) || ';';
      EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(role_name_lower) || ';';
    ELSE
      RAISE NOTICE 'Lower-case role % does not exist, skipping.', role_name_lower;
    END IF;
  END LOOP;
  RAISE NOTICE '--- CLEANUP PHASE COMPLETE ---';
END$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- ЭТАП 2: СОЗДАНИЕ НОВЫХ РОЛЕЙ И ВЫДАЧА ПРАВ (ЗАПУСТИТЬ ВТОРЫМ, ЕСЛИ ПЕРВЫЙ ПРОШЕЛ УСПЕШНО)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('Владелец', 'АдминистраторСклада', 'Работник', 'владелец', 'администраторсклада', 'работник')) THEN
    RAISE WARNING 'Old roles might still exist. Please ensure cleanup was successful or run cleanup again.';
  END IF;
END$$;

BEGIN; -- Начинаем новую транзакцию для создания ролей и прав

-- 1. Роль: владелец (без изменений в правах)
DROP ROLE IF EXISTS владелец; -- Добавляем DROP IF EXISTS и сюда для идемпотентности второго этапа
CREATE ROLE владелец WITH LOGIN PASSWORD 'owner_secure_password123';
GRANT CONNECT ON DATABASE sushi_shop_db TO владелец;
GRANT USAGE ON SCHEMA public TO владелец;
GRANT SELECT ON
    "VТекущиеОстатки", "VСписокЗаказов", "VДетализацияЗаказов",
    "VДетализацияБлюдСИнгредиентами", "VСводкаПродажПоБлюдам", "VПолнаяИнформацияПоСписаниям"
TO владелец;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO владелец;
GRANT EXECUTE ON FUNCTION создать_списание_продукта(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, NUMERIC) TO владелец;
GRANT EXECUTE ON FUNCTION создать_списание_блюда(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, INTEGER) TO владелец;
GRANT EXECUTE ON FUNCTION "РассчитатьСреднююЦенуЗакупки"(INTEGER) TO владелец;
GRANT EXECUTE ON FUNCTION "СоздатьНовыйЗаказ"(INTEGER, INTEGER, OUT INTEGER) TO владелец;
GRANT EXECUTE ON FUNCTION "ДобавитьПозициюВЗаказ"(INTEGER, INTEGER, INTEGER) TO владелец;

-- 2. Роль: администраторсклада
DROP ROLE IF EXISTS администраторсклада;
CREATE ROLE администраторсклада WITH LOGIN PASSWORD 'admin_sklad_secure_pass456';
GRANT CONNECT ON DATABASE sushi_shop_db TO администраторсклада;
GRANT USAGE ON SCHEMA public TO администраторсклада;
GRANT SELECT ON "VТекущиеОстатки", "VПолнаяИнформацияПоСписаниям" TO администраторсклада;
GRANT SELECT ON TABLE
    "Склад", "Продукт", "КатегорияПродукта", "ЕдиницаИзмерения",
    "ПричинаСписания", "Сотрудник", "ОстатокПродуктаНаСкладе", -- SELECT уже есть, это хорошо
    "Поступление", "ПозицияПоступления", "Списание", "СписаниеПродуктов", "СписаниеБлюд",
    "СоставБлюда", "Блюдо"
TO администраторсклада;

GRANT INSERT ON TABLE "Поступление", "ПозицияПоступления",
                      "Списание", "СписаниеПродуктов", "СписаниеБлюд",
                      "ОстатокПродуктаНаСкладе" -- <<< ДОБАВЬТЕ INSERT сюда (если его не было)
TO администраторсклада;

GRANT UPDATE ON TABLE "Поступление", "ПозицияПоступления",
                      "ОстатокПродуктаНаСкладе" -- UPDATE уже был, это хорошо
TO администраторсклада;

GRANT EXECUTE ON FUNCTION создать_списание_продукта(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, NUMERIC) TO администраторсклада;
GRANT EXECUTE ON FUNCTION создать_списание_блюда(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, INTEGER) TO администраторсклада;



-- 3. Роль: работник (ИЗМЕНЕНИЯ ЗДЕСЬ)
DROP ROLE IF EXISTS работник;
CREATE ROLE работник WITH LOGIN PASSWORD 'worker_secure_pass789'; -- ЗАМЕНИТЕ ПАРОЛЬ!
GRANT CONNECT ON DATABASE sushi_shop_db TO работник;
GRANT USAGE ON SCHEMA public TO работник;

GRANT SELECT ON "VСписокЗаказов", "VДетализацияЗаказов", "VДетализацияБлюдСИнгредиентами" TO работник;

GRANT SELECT ON TABLE
    "Касса", "Смена", "Блюдо", "КатегорияБлюда", "Сотрудник",
    "Заказ", "ПозицияЗаказа", "СоставБлюда"
TO работник;

GRANT INSERT ON TABLE "Заказ", "ПозицияЗаказа" TO работник;

-- РАСШИРЯЕМ ПРАВА НА UPDATE для таблицы "Заказ"
GRANT UPDATE ("Тип_оплаты", "ID_кассы", "ID_сотрудника_оформившего", "Общая_сумма") ON "Заказ" TO работник;

GRANT UPDATE ("Количество", "Цена_на_момент_заказа") ON "ПозицияЗаказа" TO работник;

GRANT DELETE ON "ПозицияЗаказа" TO работник;

GRANT EXECUTE ON FUNCTION "СоздатьНовыйЗаказ"(INTEGER, INTEGER, OUT INTEGER) TO работник;
GRANT EXECUTE ON FUNCTION "ДобавитьПозициюВЗаказ"(INTEGER, INTEGER, INTEGER) TO работник;

-- Права на последовательности (SERIAL)
DO $$
DECLARE
    r RECORD;
    rolename_var TEXT;
BEGIN
    FOR rolename_var IN SELECT unnest(ARRAY['владелец', 'администраторсклада', 'работник'])
    LOOP
        FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public')
        LOOP
            EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.' || quote_ident(r.sequence_name) || ' TO ' || quote_ident(rolename_var) || ';';
        END LOOP;
    END LOOP;
END$$;

COMMIT;