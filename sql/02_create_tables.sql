-- 02_create_tables.sql
-- Скрипт для создания структуры базы данных sushi_shop_db

BEGIN;

-- Удаление таблиц в обратном порядке зависимостей, если они существуют
DROP TABLE IF EXISTS "Смена" CASCADE;
DROP TABLE IF EXISTS "ОстатокПродуктаНаСкладе" CASCADE;
DROP TABLE IF EXISTS "СписаниеПродуктов" CASCADE;
DROP TABLE IF EXISTS "СписаниеБлюд" CASCADE;
DROP TABLE IF EXISTS "ПозицияПоступления" CASCADE;
DROP TABLE IF EXISTS "СоставБлюда" CASCADE;
DROP TABLE IF EXISTS "ПозицияЗаказа" CASCADE;
DROP TABLE IF EXISTS "Списание" CASCADE;
DROP TABLE IF EXISTS "Поступление" CASCADE;
DROP TABLE IF EXISTS "Заказ" CASCADE;
DROP TABLE IF EXISTS "Сотрудник" CASCADE;
DROP TABLE IF EXISTS "Продукт" CASCADE;
DROP TABLE IF EXISTS "Блюдо" CASCADE;
DROP TABLE IF EXISTS "Склад" CASCADE;
DROP TABLE IF EXISTS "Касса" CASCADE;
DROP TABLE IF EXISTS "ПричинаСписания" CASCADE;
DROP TABLE IF EXISTS "Должность" CASCADE;
DROP TABLE IF EXISTS "ЕдиницаИзмерения" CASCADE;
DROP TABLE IF EXISTS "КатегорияПродукта" CASCADE;
DROP TABLE IF EXISTS "КатегорияБлюда" CASCADE;

-- 1. Справочные таблицы
CREATE TABLE "КатегорияБлюда" (
    "ID_категории_блюда" SERIAL PRIMARY KEY,
    "Название" VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE "КатегорияПродукта" (
    "ID_категории_продукта" SERIAL PRIMARY KEY,
    "Название" VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE "ЕдиницаИзмерения" (
    "ID_единицы_измерения" SERIAL PRIMARY KEY,
    "Название" VARCHAR(50) NOT NULL UNIQUE,
    "Краткое_название" VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE "Должность" (
    "ID_должности" SERIAL PRIMARY KEY,
    "Название" VARCHAR(100) NOT NULL UNIQUE,
    "Ставка_в_час" NUMERIC(10, 2) NOT NULL CHECK("Ставка_в_час" >= 0)
);

CREATE TABLE "ПричинаСписания" (
    "ID_причины_списания" SERIAL PRIMARY KEY,
    "Название" VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE "Касса" (
    "ID_кассы" SERIAL PRIMARY KEY,
    "Номер_кассы" VARCHAR(50) NOT NULL UNIQUE,
    "Расположение" VARCHAR(255)
);

CREATE TABLE "Склад" (
    "ID_склада" SERIAL PRIMARY KEY,
    "Название" VARCHAR(100) NOT NULL UNIQUE,
    "Адрес" VARCHAR(255)
);

-- 2. Таблицы, зависящие от справочников
CREATE TABLE "Блюдо" (
    "ID_блюда" SERIAL PRIMARY KEY,
    "ID_категории_блюда" INTEGER NOT NULL REFERENCES "КатегорияБлюда"("ID_категории_блюда"),
    "Название" VARCHAR(255) NOT NULL UNIQUE,
    "Цена_продажи" NUMERIC(10, 2) NOT NULL CHECK("Цена_продажи" >= 0)
);

CREATE TABLE "Продукт" (
    "ID_продукта" SERIAL PRIMARY KEY,
    "ID_категории_продукта" INTEGER NOT NULL REFERENCES "КатегорияПродукта"("ID_категории_продукта"),
    "ID_единицы_измерения" INTEGER NOT NULL REFERENCES "ЕдиницаИзмерения"("ID_единицы_измерения"),
    "Название" VARCHAR(255) NOT NULL UNIQUE,
    "Срок_годности_дни" INTEGER CHECK("Срок_годности_дни" > 0)
);

CREATE TABLE "Сотрудник" (
    "ID_сотрудника" SERIAL PRIMARY KEY,
    "ID_должности" INTEGER NOT NULL REFERENCES "Должность"("ID_должности"),
    "Фамилия" VARCHAR(100) NOT NULL,
    "Имя" VARCHAR(100) NOT NULL,
    "Отчество" VARCHAR(100),
    "Телефон" VARCHAR(20) UNIQUE,
    "Дата_приема" DATE NOT NULL DEFAULT CURRENT_DATE,
    "Активен" BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. Операционные таблицы
CREATE TABLE "Заказ" (
    "ID_заказа" SERIAL PRIMARY KEY,
    "ID_кассы" INTEGER NOT NULL REFERENCES "Касса"("ID_кассы"),
    "ID_сотрудника_оформившего" INTEGER NOT NULL REFERENCES "Сотрудник"("ID_сотрудника"),
    "Дата_создания" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Тип_оплаты" VARCHAR(50),
    "Общая_сумма" NUMERIC(12, 2) DEFAULT 0 CHECK("Общая_сумма" >= 0)
);

CREATE TABLE "Поступление" (
    "ID_поступления" SERIAL PRIMARY KEY,
    "ID_склада" INTEGER NOT NULL REFERENCES "Склад"("ID_склада"),
    "ID_сотрудника_принявшего" INTEGER NOT NULL REFERENCES "Сотрудник"("ID_сотрудника"),
    "Дата_поступления" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Номер_накладной" VARCHAR(50)
);

CREATE TABLE "Списание" (
    "ID_списания" SERIAL PRIMARY KEY,
    "ID_склада" INTEGER NOT NULL REFERENCES "Склад"("ID_склада"),
    "ID_сотрудника_ответственного" INTEGER NOT NULL REFERENCES "Сотрудник"("ID_сотрудника"),
    "ID_причины_списания" INTEGER NOT NULL REFERENCES "ПричинаСписания"("ID_причины_списания"),
    "Дата_списания" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Комментарий" TEXT
);

-- 4. Ассоциативные таблицы, таблицы деталей и наследуемые таблицы
CREATE TABLE "ПозицияЗаказа" (
    "ID_заказа" INTEGER NOT NULL REFERENCES "Заказ"("ID_заказа") ON DELETE CASCADE,
    "ID_блюда" INTEGER NOT NULL REFERENCES "Блюдо"("ID_блюда"),
    "Количество" INTEGER NOT NULL CHECK("Количество" > 0),
    "Цена_на_момент_заказа" NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY ("ID_заказа", "ID_блюда")
);

CREATE TABLE "СоставБлюда" (
    "ID_блюда" INTEGER NOT NULL REFERENCES "Блюдо"("ID_блюда") ON DELETE CASCADE,
    "ID_продукта" INTEGER NOT NULL REFERENCES "Продукт"("ID_продукта") ON DELETE CASCADE,
    "Количество" NUMERIC(10, 3) NOT NULL CHECK("Количество" > 0),
    PRIMARY KEY ("ID_блюда", "ID_продукта")
);

CREATE TABLE "ПозицияПоступления" (
    "ID_поступления" INTEGER NOT NULL REFERENCES "Поступление"("ID_поступления") ON DELETE CASCADE,
    "ID_продукта" INTEGER NOT NULL REFERENCES "Продукт"("ID_продукта"),
    "Количество" NUMERIC(10, 3) NOT NULL CHECK("Количество" > 0),
    "Цена_закупки" NUMERIC(10, 2) NOT NULL CHECK("Цена_закупки" >= 0),
    PRIMARY KEY ("ID_поступления", "ID_продукта")
);

CREATE TABLE "СписаниеБлюд" (
    "ID_блюда" INTEGER NOT NULL REFERENCES "Блюдо"("ID_блюда"),
    "Количество" INTEGER NOT NULL CHECK("Количество" > 0),
    FOREIGN KEY ("ID_списания") REFERENCES "Списание"("ID_списания") ON DELETE CASCADE
) INHERITS ("Списание");

CREATE TABLE "СписаниеПродуктов" (
    "ID_продукта" INTEGER NOT NULL REFERENCES "Продукт"("ID_продукта"),
    "Количество" NUMERIC(10, 3) NOT NULL CHECK("Количество" > 0),
    FOREIGN KEY ("ID_списания") REFERENCES "Списание"("ID_списания") ON DELETE CASCADE
) INHERITS ("Списание");

CREATE TABLE "ОстатокПродуктаНаСкладе" (
    "ID_склада" INTEGER NOT NULL REFERENCES "Склад"("ID_склада") ON DELETE CASCADE,
    "ID_продукта" INTEGER NOT NULL REFERENCES "Продукт"("ID_продукта") ON DELETE CASCADE,
    "Количество" NUMERIC(10, 3) NOT NULL DEFAULT 0 CHECK("Количество" >= 0),
    PRIMARY KEY ("ID_склада", "ID_продукта")
);

CREATE TABLE "Смена" (
    "ID_смены" SERIAL PRIMARY KEY,
    "ID_сотрудника" INTEGER NOT NULL REFERENCES "Сотрудник"("ID_сотрудника"),
    "ID_склада" INTEGER REFERENCES "Склад"("ID_склада"),
    "Дата_смены" DATE NOT NULL DEFAULT CURRENT_DATE,
    "Время_начала" TIME NOT NULL,
    "Время_окончания" TIME,
    CHECK ("Время_окончания" IS NULL OR "Время_окончания" > "Время_начала")
);

-- 5. Создание индексов
CREATE INDEX IF NOT EXISTS "idx_Блюдо_ID_категории_блюда" ON "Блюдо"("ID_категории_блюда");
CREATE INDEX IF NOT EXISTS "idx_Продукт_ID_категории_продукта" ON "Продукт"("ID_категории_продукта");
CREATE INDEX IF NOT EXISTS "idx_Продукт_ID_единицы_измерения" ON "Продукт"("ID_единицы_измерения");
CREATE INDEX IF NOT EXISTS "idx_Сотрудник_ID_должности" ON "Сотрудник"("ID_должности");
CREATE INDEX IF NOT EXISTS "idx_Заказ_ID_кассы" ON "Заказ"("ID_кассы");
CREATE INDEX IF NOT EXISTS "idx_Заказ_ID_сотрудника_оформившего" ON "Заказ"("ID_сотрудника_оформившего");
CREATE INDEX IF NOT EXISTS "idx_Заказ_Дата_создания" ON "Заказ"("Дата_создания");
CREATE INDEX IF NOT EXISTS "idx_Поступление_ID_склада" ON "Поступление"("ID_склада");
CREATE INDEX IF NOT EXISTS "idx_Поступление_ID_сотрудника_приняв" ON "Поступление"("ID_сотрудника_принявшего");
CREATE INDEX IF NOT EXISTS "idx_Поступление_Дата_поступления" ON "Поступление"("Дата_поступления");
CREATE INDEX IF NOT EXISTS "idx_Списание_ID_склада" ON "Списание"("ID_склада");
CREATE INDEX IF NOT EXISTS "idx_Списание_ID_сотрудника_ответстве" ON "Списание"("ID_сотрудника_ответственного");
CREATE INDEX IF NOT EXISTS "idx_Списание_ID_причины_списания" ON "Списание"("ID_причины_списания");
CREATE INDEX IF NOT EXISTS "idx_Списание_Дата_списания" ON "Списание"("Дата_списания");
CREATE INDEX IF NOT EXISTS "idx_ПозицияЗаказа_ID_блюда" ON "ПозицияЗаказа"("ID_блюда");
CREATE INDEX IF NOT EXISTS "idx_СоставБлюда_ID_продукта" ON "СоставБлюда"("ID_продукта");
CREATE INDEX IF NOT EXISTS "idx_ПозицияПоступления_ID_продукта" ON "ПозицияПоступления"("ID_продукта");
CREATE UNIQUE INDEX IF NOT EXISTS "idx_unique_СписаниеБлюд_ID_списания" ON "СписаниеБлюд"("ID_списания");
CREATE INDEX IF NOT EXISTS "idx_СписаниеБлюд_ID_блюда" ON "СписаниеБлюд"("ID_блюда");
CREATE UNIQUE INDEX IF NOT EXISTS "idx_unique_СписаниеПродуктов_ID_списания" ON "СписаниеПродуктов"("ID_списания");
CREATE INDEX IF NOT EXISTS "idx_СписаниеПродуктов_ID_продукта" ON "СписаниеПродуктов"("ID_продукта");
CREATE INDEX IF NOT EXISTS "idx_ОстатокПродуктаНаСкладе_ID_прод" ON "ОстатокПродуктаНаСкладе"("ID_продукта");
CREATE INDEX IF NOT EXISTS "idx_Смена_ID_сотрудника" ON "Смена"("ID_сотрудника");
CREATE INDEX IF NOT EXISTS "idx_Смена_ID_склада" ON "Смена"("ID_склада");
CREATE INDEX IF NOT EXISTS "idx_Смена_Дата_смены" ON "Смена"("Дата_смены");

COMMIT;