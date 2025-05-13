-- 08_create_roles_and_permissions.sql
-- Создание ролей пользователей и назначение прав доступа
-- Используется имя базы данных "sushi_shop_db" (измените, если ваше отличается)

BEGIN;

-- 1. Роль: "Владелец"
-- Удаляем роль, если существует, чтобы избежать ошибки при повторном запуске (для разработки)
DROP ROLE IF EXISTS "Владелец";
CREATE ROLE "Владелец" WITH LOGIN PASSWORD 'owner_secure_password123'; -- ЗАМЕНИТЕ ПАРОЛЬ!

GRANT CONNECT ON DATABASE "sushi_shop_db" TO "Владелец";
GRANT USAGE ON SCHEMA public TO "Владелец";

-- Права на представления (используем те, что создали в 06_create_views.sql)
GRANT SELECT ON
    "VТекущиеОстатки",
    "VСписокЗаказов",
    "VДетализацияЗаказов",
    "VДетализацияБлюдСИнгредиентами",
    "VСводкаПродажПоБлюдам",
    "VПолнаяИнформацияПоСписаниям"
TO "Владелец";

-- Права на таблицы (все таблицы на SELECT для владельца)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "Владелец";

-- Права на функции (пример, если будет такая функция)
-- GRANT EXECUTE ON FUNCTION "РассчитатьСреднююЦенуЗакупки"(INTEGER) TO "Владелец";
-- Выдадим права на существующие функции для полноты
GRANT EXECUTE ON FUNCTION "создать_списание_продукта"(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, NUMERIC) TO "Владелец";
GRANT EXECUTE ON FUNCTION "создать_списание_блюда"(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, INTEGER) TO "Владелец";


-- 2. Роль: "АдминистраторСклада"
DROP ROLE IF EXISTS "АдминистраторСклада";
CREATE ROLE "АдминистраторСклада" WITH LOGIN PASSWORD 'admin_sklad_secure_pass456'; -- ЗАМЕНИТЕ ПАРОЛЬ!

GRANT CONNECT ON DATABASE "sushi_shop_db" TO "АдминистраторСклада";
GRANT USAGE ON SCHEMA public TO "АдминистраторСклада";

-- Права на представления
GRANT SELECT ON "VТекущиеОстатки" TO "АдминистраторСклада";
GRANT SELECT ON "VПолнаяИнформацияПоСписаниям" TO "АдминистраторСклада";

-- Права на таблицы
GRANT SELECT ON TABLE
    "Склад", "Продукт", "КатегорияПродукта", "ЕдиницаИзмерения",
    "ПричинаСписания", "Сотрудник", "ОстатокПродуктаНаСкладе",
    "Поступление", "ПозицияПоступления", "Списание", "СписаниеПродуктов", "СписаниеБлюд",
    "СоставБлюда" -- Чтобы видеть, из чего состоят блюда при списании
TO "АдминистраторСклада";

-- Права на INSERT для операций, которые он выполняет
GRANT INSERT ON TABLE "Поступление", "ПозицияПоступления" TO "АдминистраторСклада";
-- Для списаний используются функции, поэтому прямой INSERT в таблицы списаний не даем.

-- Права на UPDATE (например, для коррекции данных поступления, если разрешено)
GRANT UPDATE ON TABLE "Поступление", "ПозицияПоступления" TO "АдминистраторСклада";
-- Возможность ручной коррекции остатков (с ОЧЕНЬ большой осторожностью и логированием в приложении!)
GRANT UPDATE ON TABLE "ОстатокПродуктаНаСкладе" TO "АдминистраторСклада";

-- Права на функции
GRANT EXECUTE ON FUNCTION "создать_списание_продукта"(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, NUMERIC) TO "АдминистраторСклада";
GRANT EXECUTE ON FUNCTION "создать_списание_блюда"(INTEGER, INTEGER, INTEGER, TEXT, INTEGER, INTEGER) TO "АдминистраторСклада";
-- Если будет функция "ПровестиПоступление", то:
-- GRANT EXECUTE ON FUNCTION "ПровестиПоступление"(/* параметры */) TO "АдминистраторСклада";


-- 3. Роль: "Работник" (например, кассир)
DROP ROLE IF EXISTS "Работник";
CREATE ROLE "Работник" WITH LOGIN PASSWORD 'worker_secure_pass789'; -- ЗАМЕНИТЕ ПАРОЛЬ!

GRANT CONNECT ON DATABASE "sushi_shop_db" TO "Работник";
GRANT USAGE ON SCHEMA public TO "Работник";

-- Права на представления
GRANT SELECT ON "VСписокЗаказов", "VДетализацияЗаказов" TO "Работник";
GRANT SELECT ON "VДетализацияБлюдСИнгредиентами" TO "Работник"; -- Чтобы видеть состав блюд

-- Права на таблицы
GRANT SELECT ON TABLE
    "Касса", "Смена", "Блюдо", "КатегорияБлюда", "Сотрудник", -- Сотрудник - для выбора оформившего заказ
    "Заказ", "ПозицияЗаказа" -- Для просмотра своих или всех заказов (в зависимости от политики)
TO "Работник";

GRANT INSERT ON TABLE "Заказ", "ПозицияЗаказа" TO "Работник";

-- Общая сумма должна обновляться автоматически (триггером или процедурой "ДобавитьПозициюВЗаказ")
-- СтатусЗаказа мы решили не добавлять, поэтому убираем его из UPDATE
GRANT UPDATE ("Тип_оплаты") ON "Заказ" TO "Работник";
-- Если нужно обновлять сотрудника или кассу в заказе (редко, но возможно для исправления ошибок)
GRANT UPDATE ("ID_кассы", "ID_сотрудника_оформившего") ON "Заказ" TO "Работник";


GRANT DELETE ON "ПозицияЗаказа" TO "Работник"; -- Возможность удалить позицию из нового/редактируемого заказа

-- Права на функции (если будут созданы такие агрегирующие функции)
-- CREATE PROCEDURE "СоздатьНовыйЗаказ"(id_кассы_вход INTEGER, id_сотрудника_вход INTEGER, INOUT id_нового_заказа_выход INTEGER)
-- CREATE PROCEDURE "ДобавитьПозициюВЗаказ"(id_заказа_вход INTEGER, id_блюда_вход INTEGER, количество_вход INTEGER)
-- Если такие процедуры будут, то:
-- GRANT EXECUTE ON PROCEDURE "СоздатьНовыйЗаказ"(INTEGER, INTEGER, INOUT INTEGER) TO "Работник";
-- GRANT EXECUTE ON PROCEDURE "ДобавитьПозициюВЗаказ"(INTEGER, INTEGER, INTEGER) TO "Работник";


-- Важно: Дать права на последовательности (SERIAL) для тех таблиц, куда роли могут делать INSERT
-- Этот блок должен выполняться от имени суперпользователя (например, postgres)
-- или пользователя, создавшего эти последовательности.
-- Он выдаст права всем трем созданным ролям.
DO $$
DECLARE
    r RECORD;
    rolename TEXT;
BEGIN
    FOR rolename IN SELECT unnest(ARRAY['Владелец', 'АдминистраторСклада', 'Работник'])
    LOOP
        FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public')
        LOOP
            EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.' || quote_ident(r.sequence_name) || ' TO ' || quote_ident(rolename) || ';';
        END LOOP;
    END LOOP;
END$$;

-- Установка прав по умолчанию для БУДУЩИХ объектов (если нужно)
-- Это может быть полезно, но для курсовой явных GRANT обычно достаточно.
/*
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "Владелец";
ALTER DEFAULT PRIVILEGES FOR ROLE "имя_создателя_объектов_если_не_суперюзер" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "АдминистраторСклада";
ALTER DEFAULT PRIVILEGES FOR ROLE "имя_создателя_объектов_если_не_суперюзер" IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO "Работник";

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO "Владелец", "АдминистраторСклада", "Работник";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO "Владелец", "АдминистраторСклада", "Работник";
*/

COMMIT;
