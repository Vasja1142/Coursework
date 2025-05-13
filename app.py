# app.py
from flask import Flask, render_template, request, redirect, url_for, g, session, flash
import psycopg2
import psycopg2.extras # для удобного получения данных в виде словарей
from functools import wraps # для декораторов

app = Flask(__name__)
app.secret_key = 'sushi_shop_super_secret_key_123!' # ЗАМЕНИТЕ ЭТО НА СВОЙ УНИКАЛЬНЫЙ КЛЮЧ!

# --- Конфигурация подключения к БД ---
DB_HOST = "localhost"
DB_NAME = "sushi_shop_db"
DB_PORT = "5432"

DB_USERS = {
    "Владелец": ("владелец", "owner_secure_password123"),
    "АдминистраторСклада": ("администраторсклада", "admin_sklad_secure_pass456"),
    "Работник": ("работник", "worker_secure_pass789"),
}

# Список возможных типов оплаты
PAYMENT_TYPES = ["Наличные", "Карта", "Онлайн", "Смешанная"]


def get_db_connection():
    if 'current_role_key' not in session:
        return None
    role_display_name = session['current_role_key']
    role_credentials = DB_USERS.get(role_display_name)
    if not role_credentials:
        flash(f"Неверные учетные данные для роли: {role_display_name}", "error")
        session.pop('current_role_key', None)
        return None
    try:
        conn = psycopg2.connect(
            host=DB_HOST, database=DB_NAME, user=role_credentials[0],
            password=role_credentials[1], port=DB_PORT
        )
        return conn
    except psycopg2.Error as e:
        flash(f"Ошибка подключения к БД под ролью {role_display_name}: {e}", "error")
        print(f"DB Connection Error for role {role_display_name} (user: {role_credentials[0]}): {e}")
        session.pop('current_role_key', None)
        return None

@app.before_request
def before_request():
    g.db_conn = get_db_connection()

@app.teardown_request
def teardown_request(exception):
    db_conn = g.pop('db_conn', None)
    if db_conn is not None:
        db_conn.close()

# --- Маршруты (Routes) ---
@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        role_key_selected = request.form.get('role')
        if role_key_selected in DB_USERS:
            session['current_role_key'] = role_key_selected
            flash(f"Вы вошли как: {role_key_selected}", "success")
            if role_key_selected == "Владелец": return redirect(url_for('owner_dashboard'))
            if role_key_selected == "АдминистраторСклада": return redirect(url_for('admin_sklad_dashboard'))
            if role_key_selected == "Работник": return redirect(url_for('worker_dashboard'))
        else:
            flash("Неверная роль выбрана.", "error")
    return render_template('index.html', roles=DB_USERS.keys())

@app.route('/logout')
def logout():
    session.pop('current_role_key', None)
    flash("Вы вышли из системы.", "info")
    return redirect(url_for('index'))

# --- Функции-декораторы для проверки ролей ---
def login_required(role_keys):
    if not isinstance(role_keys, list): role_keys = [role_keys]
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'current_role_key' not in session or session['current_role_key'] not in role_keys:
                flash(f"Доступ запрещен. Требуется одна из ролей: {', '.join(role_keys)}.", "warning")
                return redirect(url_for('index'))
            if not g.db_conn:
                 flash("Ошибка подключения к БД. Пожалуйста, попробуйте войти снова.", "error")
                 return redirect(url_for('index'))
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# --- Панели управления для ролей ---
@app.route('/owner')
@login_required("Владелец")
def owner_dashboard():
    return render_template('owner_dashboard.html')

@app.route('/admin_sklad')
@login_required("АдминистраторСклада")
def admin_sklad_dashboard():
    return render_template('admin_sklad_dashboard.html')

@app.route('/worker')
@login_required("Работник")
def worker_dashboard():
    return render_template('worker_dashboard.html')

# --- Страницы для Владельца (без изменений) ---
@app.route('/owner/stock_balance')
@login_required("Владелец")
def owner_stock_balance():
    items = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT * FROM "VТекущиеОстатки";')
            items = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении данных об остатках: {e}", "error")
    return render_template('owner_stock_balance.html', items=items, title="Текущие остатки")

@app.route('/owner/orders_list')
@login_required("Владелец")
def owner_orders_list():
    orders = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT * FROM "VСписокЗаказов";')
            orders = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении списка заказов: {e}", "error")
    return render_template('owner_generic_list.html', items=orders, title="Список Заказов",
                           headers=["ID Заказа", "Дата создания", "Сотрудник", "Номер кассы", "Расположение кассы", "Тип оплаты", "Общая сумма"])

@app.route('/owner/dishes_details')
@login_required("Владелец")
def owner_dishes_details():
    details = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT * FROM "VДетализацияБлюдСИнгредиентами";')
            details = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении детализации блюд: {e}", "error")
    return render_template('owner_generic_list.html', items=details, title="Детализация Блюд с Ингредиентами",
                           headers=["Блюдо", "Категория блюда", "Цена блюда", "Ингредиент", "Категория ингредиента", "Кол-во ингредиента", "Ед. изм."])

@app.route('/owner/sales_summary_by_dish')
@login_required("Владелец")
def owner_sales_summary_by_dish():
    summary = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT * FROM "VСводкаПродажПоБлюдам";')
            summary = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении сводки продаж: {e}", "error")
    return render_template('owner_generic_list.html', items=summary, title="Сводка Продаж по Блюдам",
                           headers=["Блюдо", "Категория блюда", "Продано порций", "Общая сумма продаж"])

@app.route('/owner/write_offs_full')
@login_required("Владелец")
def owner_write_offs_full():
    write_offs = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT * FROM "VПолнаяИнформацияПоСписаниям";')
            write_offs = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении информации по списаниям: {e}", "error")
    return render_template('owner_generic_list.html', items=write_offs, title="Полная Информация по Списаниям",
                           headers=["ID Списания", "Дата", "Склад", "Сотрудник", "Причина", "Тип объекта", "Наименование", "Кол-во", "Ед. изм.", "Комментарий"])


# --- Страницы и логика для РОЛИ "Работник" ---

@app.route('/worker/menu')
@login_required("Работник")
def worker_menu():
    dishes = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT b."ID_блюда", b."Название", b."Цена_продажи", kb."Название" AS "Категория" FROM "Блюдо" b JOIN "КатегорияБлюда" kb ON b."ID_категории_блюда" = kb."ID_категории_блюда" ORDER BY kb."Название", b."Название";')
            dishes = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при получении меню: {e}", "error")
    return render_template('worker_menu.html', dishes=dishes)

@app.route('/worker/create_order', methods=['GET', 'POST'])
@login_required("Работник")
def worker_create_order():
    kassy = []
    sotrudniki = []
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT "ID_кассы", "Номер_кассы" FROM "Касса" ORDER BY "Номер_кассы";')
            kassy = cur.fetchall()
            cur.execute('SELECT "ID_сотрудника", "Фамилия", "Имя" FROM "Сотрудник" WHERE "Активен" = TRUE ORDER BY "Фамилия";')
            sotrudniki = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при загрузке данных для формы заказа: {e}", "error")
        return redirect(url_for('worker_dashboard'))

    if request.method == 'POST':
        id_kassy_form = request.form.get('id_kassy')
        id_sotrudnika_form = request.form.get('id_sotrudnika')
        if not id_kassy_form or not id_sotrudnika_form:
            flash("Необходимо выбрать кассу и сотрудника.", "error")
        else:
            try:
                new_order_id = None
                with g.db_conn.cursor() as cur:
                    cur.callproc('"СоздатьНовыйЗаказ"', (int(id_kassy_form), int(id_sotrudnika_form)))
                    result = cur.fetchone()
                    if result: new_order_id = result[0]
                if new_order_id:
                    g.db_conn.commit()
                    flash(f"Новый заказ #{new_order_id} успешно создан!", "success")
                    return redirect(url_for('worker_add_item_to_order', order_id=new_order_id))
                else:
                    g.db_conn.rollback()
                    flash("Не удалось создать заказ (не получен ID).", "error")
            except psycopg2.Error as e:
                g.db_conn.rollback()
                flash(f"Ошибка базы данных при создании заказа: {e}", "error")
            except ValueError:
                flash("Некорректные ID кассы или сотрудника.", "error")
    return render_template('worker_create_order.html', kassy=kassy, sotrudniki=sotrudniki)


@app.route('/worker/order/<int:order_id>/add_item', methods=['GET', 'POST'])
@login_required("Работник")
def worker_add_item_to_order(order_id):
    order_info = None
    order_items = []
    all_dishes = []

    # Обработка POST-запроса ДО загрузки данных для GET, чтобы изменения сразу отразились
    if request.method == 'POST':
        # Определяем, какая форма была отправлена
        form_name = request.form.get('form_name')

        if form_name == 'add_dish_item':
            dish_id_form = request.form.get('dish_id')
            quantity_form = request.form.get('quantity')
            if not dish_id_form or not quantity_form:
                flash("Необходимо выбрать блюдо и указать количество.", "error")
            else:
                try:
                    dish_id = int(dish_id_form)
                    quantity = int(quantity_form)
                    if quantity <= 0:
                        flash("Количество должно быть больше нуля.", "error")
                    else:
                        with g.db_conn.cursor() as cur:
                            cur.callproc('"ДобавитьПозициюВЗаказ"', (order_id, dish_id, quantity))
                        g.db_conn.commit()
                        flash(f"Блюдо успешно добавлено/обновлено в заказе #{order_id}!", "success")
                        # Перезагружаем страницу, чтобы увидеть обновленные позиции и сумму
                        return redirect(url_for('worker_add_item_to_order', order_id=order_id))
                except psycopg2.Error as e:
                    g.db_conn.rollback()
                    flash(f"Ошибка базы данных при добавлении позиции: {e}", "error")
                except ValueError:
                    flash("Некорректный ID блюда или количество.", "error")

        elif form_name == 'update_payment_type':
            payment_type_form = request.form.get('payment_type')
            if payment_type_form and payment_type_form in PAYMENT_TYPES:
                try:
                    with g.db_conn.cursor() as cur:
                        cur.execute('UPDATE "Заказ" SET "Тип_оплаты" = %s WHERE "ID_заказа" = %s;',
                                    (payment_type_form, order_id))
                    g.db_conn.commit()
                    flash(f"Тип оплаты для заказа #{order_id} обновлен на '{payment_type_form}'.", "success")
                    return redirect(url_for('worker_add_item_to_order', order_id=order_id)) # Перезагрузка
                except psycopg2.Error as e:
                    g.db_conn.rollback()
                    flash(f"Ошибка базы данных при обновлении типа оплаты: {e}", "error")
            elif payment_type_form == "": # Если выбрали "не указан"
                 try:
                    with g.db_conn.cursor() as cur:
                        cur.execute('UPDATE "Заказ" SET "Тип_оплаты" = NULL WHERE "ID_заказа" = %s;', (order_id,))
                    g.db_conn.commit()
                    flash(f"Тип оплаты для заказа #{order_id} сброшен.", "success")
                    return redirect(url_for('worker_add_item_to_order', order_id=order_id))
                 except psycopg2.Error as e:
                    g.db_conn.rollback()
                    flash(f"Ошибка базы данных при сбросе типа оплаты: {e}", "error")
            else:
                flash("Некорректный тип оплаты.", "error")


    # Загрузка данных для GET-запроса (или после POST для обновления)
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute('SELECT z.*, s."Фамилия" as "Фамилия_сотрудника", s."Имя" as "Имя_сотрудника", k."Номер_кассы" FROM "Заказ" z JOIN "Сотрудник" s ON z."ID_сотрудника_оформившего" = s."ID_сотрудника" JOIN "Касса" k ON z."ID_кассы" = k."ID_кассы" WHERE z."ID_заказа" = %s;', (order_id,))
            order_info = cur.fetchone()
            if not order_info:
                flash(f"Заказ #{order_id} не найден.", "error")
                return redirect(url_for('worker_dashboard'))
            cur.execute('SELECT pz."ID_блюда", b."Название" AS "Название_блюда", pz."Количество", pz."Цена_на_момент_заказа", (pz."Количество" * pz."Цена_на_момент_заказа") AS "Сумма_позиции" FROM "ПозицияЗаказа" pz JOIN "Блюдо" b ON pz."ID_блюда" = b."ID_блюда" WHERE pz."ID_заказа" = %s ORDER BY b."Название";', (order_id,))
            order_items = cur.fetchall()
            cur.execute('SELECT "ID_блюда", "Название", "Цена_продажи" FROM "Блюдо" ORDER BY "Название";')
            all_dishes = cur.fetchall()
    except psycopg2.Error as e:
        flash(f"Ошибка при загрузке данных для заказа #{order_id}: {e}", "error")
        if not order_info: # Если заказ не найден, то редирект
             return redirect(url_for('worker_dashboard'))

    return render_template('worker_add_item_to_order.html',
                           order_id=order_id,
                           order_info=order_info,
                           order_items=order_items,
                           all_dishes=all_dishes,
                           payment_types=PAYMENT_TYPES) # Передаем список типов оплаты в шаблон


if __name__ == '__main__':
    app.run(debug=True)