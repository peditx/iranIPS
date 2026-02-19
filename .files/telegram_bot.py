# Version 11.4 - Full Code Fixed & Handler Order Corrected
# Logic: Specific handlers (Tickets, Admin actions) are added BEFORE the main conversation handler.

import logging
import re
import uuid
import json
import traceback
import secrets
import socket
from pathlib import Path
from datetime import datetime, timezone, timedelta
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor, Json
from werkzeug.security import generate_password_hash, check_password_hash

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, KeyboardButton, ReplyKeyboardMarkup, ReplyKeyboardRemove
from telegram.ext import (
    Application, CommandHandler, ContextTypes, ConversationHandler,
    CallbackQueryHandler, MessageHandler, filters,
)
from telegram.constants import ParseMode
from telegram.error import BadRequest

# --- CONFIGURATION ---
BOT_TOKEN = "7261754816:AAE1otWzdY8cPARa4jkqqdiDBw3b7v9mols"
ROOT_ADMIN_CHAT_ID = 233753768
BASE_URL = "https://firmware.peditxos.ir"
ADMINS_FILE = Path("/opt/peditxos_api/admins.json")
PLANS_FILE = Path("/opt/peditxos_api/plans.json")
PAYMENT_SETTINGS_FILE = Path("/opt/peditxos_api/payment_settings.json")
BROADCAST_SLEEP_DELAY = 0.1

# --- لیست دامنه‌های ایمیل موقت و فیک ---
DISPOSABLE_DOMAINS = {
    "tempmail.com", "10minutemail.com", "guerrillamail.com", "sharklasers.com",
    "yopmail.com", "mailinator.com", "throwawaymail.com", "temp-mail.org",
    "fake-email.com", "emlpro.com", "emlhub.com", "spam4.me"
}

logging.basicConfig(format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Database Connection Helper ---
def get_db_connection():
    """ Persistent connection to PostgreSQL database """
    try:
        conn = psycopg2.connect(
            dbname="peditxos_db",
            user="pedit_user",
            password='PeD@20132013..',
            host="localhost"
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None

def init_db():
    """
    Initialize tables compatible with Backend Schema.
    """
    conn = get_db_connection()
    if not conn:
        print("!!! CRITICAL: Cannot connect to database to initialize tables.")
        return

    commands = [
        # users table matching backend_app.py (User model)
        """
        CREATE TABLE IF NOT EXISTS users (
            uid VARCHAR(128) PRIMARY KEY,
            email VARCHAR(120) UNIQUE NOT NULL,
            password_hash VARCHAR(255),
            display_name VARCHAR(255),
            tokens INTEGER DEFAULT 0,
            is_admin BOOLEAN DEFAULT FALSE,
            is_verified BOOLEAN DEFAULT FALSE,
            verification_token VARCHAR(100),
            token_expiry TIMESTAMP,
            last_verification_sent TIMESTAMP,
            telegram_photo_file_id VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            phone_number VARCHAR(50), 
            language_code VARCHAR(10) DEFAULT 'fa',
            last_build_timestamp TIMESTAMP
        )
        """,
        # telegram_users table matching backend_app.py (TelegramUser model)
        """
        CREATE TABLE IF NOT EXISTS telegram_users (
            email VARCHAR(120) PRIMARY KEY,
            chat_id BIGINT NOT NULL
        )
        """,
        # Bot specific tables
        """
        CREATE TABLE IF NOT EXISTS support_tickets (
            ticket_id VARCHAR(50) PRIMARY KEY,
            user_email VARCHAR(255) NOT NULL,
            user_chat_id BIGINT,
            user_full_name VARCHAR(255),
            message_text TEXT,
            status VARCHAR(50) DEFAULT 'open',
            admin_message_ids JSONB DEFAULT '{}',
            history JSONB DEFAULT '[]',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            closed_by VARCHAR(255),
            closed_at TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS purchase_orders (
            tracking_code VARCHAR(50) PRIMARY KEY,
            user_email VARCHAR(255) NOT NULL,
            user_full_name VARCHAR(255),
            user_chat_id BIGINT,
            plan_key VARCHAR(100),
            status VARCHAR(50) DEFAULT 'pending',
            payment_method VARCHAR(50),
            admin_message_ids JSONB DEFAULT '{}',
            processed_by VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    ]
    try:
        cur = conn.cursor()
        for command in commands:
            cur.execute(command)
        conn.commit()
        cur.close()
        conn.close()
        print("--> Database initialized successfully (Tables synced with Backend).")
    except Exception as e:
        print(f"!!! Error initializing database: {e}")

# --- Multilingual Support ---
SUPPORTED_LANGUAGES = {
    'fa': 'فارسی', 'en': 'English', 'ru': 'Русский',
    'zh': '中文', 'ar': 'العربية', 'tr': 'Türkçe'
}
translations = {}

def load_translations():
    locales_dir = Path(__file__).parent / 'locales'
    if not locales_dir.exists():
        locales_dir.mkdir(exist_ok=True)
    for lang_code in SUPPORTED_LANGUAGES:
        lang_file = locales_dir / f"{lang_code}.json"
        if lang_file.exists():
            try:
                with open(lang_file, "r", encoding="utf-8") as f:
                    translations[lang_code] = json.load(f)
                print(f"-> Loaded translation for: {lang_code}")
            except Exception as e:
                logger.error(f"Could not load translation file {lang_file}: {e}")
        else:
            logger.warning(f"Translation file not found for language '{lang_code}': {lang_file}")

def t(key: str, context: ContextTypes.DEFAULT_TYPE, **kwargs) -> str:
    lang_code = context.user_data.get('language_code', 'fa')
    text = translations.get(lang_code, {}).get(key, translations.get('fa', {}).get(key, key))
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError):
            return text
    return text

def t_for_user(key: str, lang_code: str, **kwargs) -> str:
    text = translations.get(lang_code, {}).get(key, translations.get('fa', {}).get(key, key))
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError):
            return text
    return text

# --- CONVERSATION STATES ---
(
    SELECTING_LANGUAGE, GETTING_EMAIL, GETTING_PHONE, GETTING_PASSWORD, MAIN_MENU,
    CHOOSING_PAYMENT_METHOD, CHOOSING_PLAN, WAITING_FOR_RECEIPT, GETTING_SUPPORT_MESSAGE, ADMIN_REPLYING,
    USER_REPLYING_TO_TICKET, ADMIN_PANEL, GETTING_BROADCAST_MESSAGE, CONFIRM_BROADCAST,
    GETTING_ADD_ADMIN_ID, GETTING_REMOVE_ADMIN_ID,
    ADMIN_MANAGE_PLANS, GETTING_PLAN_TOKENS, GETTING_PLAN_PRICE, REMOVING_PLAN,
    EDITING_PLAN_SELECT, GETTING_NEW_PLAN_TOKENS, GETTING_NEW_PLAN_PRICE,
    GETTING_PLAN_PRICE_USD, GETTING_NEW_PLAN_PRICE_USD,
    ADMIN_MANAGE_PAYMENT, GETTING_CARD_NUMBER, GETTING_CARD_OWNER,
    GETTING_PAYPAL_EMAIL, GETTING_CRYPTO_ADDRESSES,
    RESET_GET_EMAIL, RESET_NEW_PASSWORD
) = range(32)


# ===============================================================
# Helper Functions
# ===============================================================
def format_price_toman(price: int) -> str:
    if not price or price == 0: return ""
    if price >= 1_000_000:
        value = price / 1_000_000
        formatted_value = int(value) if value == int(value) else f"{value:.1f}"
        return f"{formatted_value} میلیون تومان"
    elif price >= 1_000:
        value = price / 1_000
        formatted_value = int(value) if value == int(value) else f"{value:.1f}"
        return f"{formatted_value} هزار تومان"
    else:
        return f"{price} تومان"

def generate_plan_label(plan: dict) -> str:
    tokens = plan.get('tokens', 0)
    price_toman = plan.get('price', 0)
    price_usd = plan.get('price_usd', 0)
    
    label = f"{tokens} توکن"
    price_parts = []
    if price_toman > 0:
        price_parts.append(format_price_toman(price_toman))
    if price_usd > 0:
        price_parts.append(f"${price_usd:.2f}")
    
    if price_parts:
        label += f" - {' / '.join(price_parts)}"
        
    return label

def load_plans() -> dict:
    if not PLANS_FILE.exists():
        initial_plans = {
             "10_tokens_basic": {"tokens": 10, "price": 50000, "price_usd": 1.0},
             "20_tokens_standard": {"tokens": 20, "price": 90000, "price_usd": 1.8},
        }
        save_plans(initial_plans)
        return initial_plans
    try:
        with open(PLANS_FILE, "r", encoding="utf-8") as f: return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}

def save_plans(plans_data: dict) -> None:
    global PLANS
    PLANS = plans_data
    with open(PLANS_FILE, "w", encoding="utf-8") as f:
        json.dump(plans_data, f, ensure_ascii=False, indent=4)

PLANS = load_plans()

def load_admins() -> set:
    if not ADMINS_FILE.exists():
        initial_admins = {ROOT_ADMIN_CHAT_ID}
        save_admins(initial_admins)
        return initial_admins
    try:
        with open(ADMINS_FILE, "r") as f: return set(json.load(f))
    except (json.JSONDecodeError, FileNotFoundError): return {ROOT_ADMIN_CHAT_ID}

def save_admins(admin_ids_set: set) -> None:
    global admin_ids
    admin_ids = admin_ids_set
    with open(ADMINS_FILE, "w") as f:
        json.dump(list(admin_ids_set), f)

admin_ids = load_admins()

def load_payment_settings() -> dict:
    if not PAYMENT_SETTINGS_FILE.exists():
        initial_settings = {
            "card": {"number": "6219860000000000", "owner": "اسم صاحب حساب"},
            "paypal": {"email": "paypal@example.com"},
            "crypto": {
                "USDT (TRC20)": "TXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "BTC": "bc1XXXXXXXXXXXXXXXXXXXXXXXXX"
            }
        }
        save_payment_settings(initial_settings)
        return initial_settings
    try:
        with open(PAYMENT_SETTINGS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}

def save_payment_settings(settings_data: dict) -> None:
    global PAYMENT_SETTINGS
    PAYMENT_SETTINGS = settings_data
    with open(PAYMENT_SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings_data, f, ensure_ascii=False, indent=4)

PAYMENT_SETTINGS = load_payment_settings()

def is_admin(user_id: int) -> bool: return user_id in admin_ids
def is_root_admin(user_id: int) -> bool: return user_id == ROOT_ADMIN_CHAT_ID
def is_valid_email_syntax(email: str) -> bool: return re.match(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$", email) is not None

# --- NEW: Deep Email Validation ---
def validate_email_deep(email: str) -> tuple[bool, str]:
    """
    بررسی عمیق ایمیل بدون ارسال واقعی.
    """
    email = email.lower().strip()
    
    # 1. Syntax Check
    if not is_valid_email_syntax(email):
        return False, "فرمت ایمیل صحیح نیست (مثال: example@gmail.com)"
    
    domain = email.split('@')[1]
    
    # 2. Block Disposable Emails
    if domain in DISPOSABLE_DOMAINS:
        return False, "استفاده از سرویس‌های ایمیل موقت مجاز نیست. لطفاً از ایمیل معتبر (Gmail, Yahoo, ...) استفاده کنید."
        
    # 3. DNS Domain Check
    try:
        socket.gethostbyname(domain)
    except socket.gaierror:
        return False, f"دامنه ایمیل وارد شده ({domain}) معتبر نیست یا وجود ندارد. آیا اشتباه تایپی دارید؟"
    except Exception:
        pass

    return True, "OK"

# ===============================================================
# Admin Panel & Commands
# ===============================================================
async def admin_panel_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    if not is_admin(user.id):
        await update.effective_message.reply_text("⛔️ شما دسترسی به این بخش را ندارید.")
        return ConversationHandler.END

    keyboard = [
        [InlineKeyboardButton("آمار ربات 📊", callback_data="admin_stats"), InlineKeyboardButton("ارسال پیام همگانی 📢", callback_data="broadcast_start")],
        [InlineKeyboardButton("افزودن ادمین ➕", callback_data="add_admin_start"), InlineKeyboardButton("حذف ادمین ➖", callback_data="remove_admin_start")],
        [InlineKeyboardButton("لیست ادمین‌ها 📋", callback_data="admin_list"), InlineKeyboardButton("مدیریت پلن‌ها 🛒", callback_data="manage_plans")],
        [InlineKeyboardButton("تنظیمات پرداخت 💳", callback_data="manage_payment")],
        [InlineKeyboardButton("بازگشت به منوی اصلی 🔙", callback_data="start_menu")]
    ]
    text = "⚙️ **پنل مدیریت**\n\nلطفا یکی از گزینه‌ها را انتخاب کنید:"
    if update.callback_query:
        await update.callback_query.answer()
        await update.callback_query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    else:
        await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_PANEL

async def stats_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM users")
                users_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM telegram_users")
                tg_users_count = cur.fetchone()[0]
            text = f"📊 **آمار ربات**\n\n- تعداد کل کاربران سیستم: **{users_count}**\n- تعداد کاربران متصل به تلگرام: **{tg_users_count}**"
        except Exception as e:
            logger.error(f"Error stats: {e}")
            text = "خطا در دریافت آمار."
        finally:
            conn.close()
    else:
        text = "خطای اتصال به دیتابیس."

    keyboard = [[InlineKeyboardButton("بازگشت 🔙", callback_data="admin_panel_show")]]
    await query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_PANEL

async def list_admins_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    admin_list_str = "\n".join(f"- `{admin_id}` {'(Root)' if admin_id == ROOT_ADMIN_CHAT_ID else ''}" for admin_id in admin_ids)
    text = f"📋 **لیست ادمین‌های فعلی**\n\n{admin_list_str}"
    keyboard = [[InlineKeyboardButton("بازگشت 🔙", callback_data="admin_panel_show")]]
    await query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_PANEL

async def add_admin_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    if not is_root_admin(query.from_user.id):
        await query.answer("⛔️ این دستور فقط توسط ادمین اصلی قابل استفاده است.", show_alert=True)
        return ADMIN_PANEL
    await query.answer()
    await query.message.edit_text("لطفا شناسه عددی (Chat ID) ادمین جدید را وارد کنید.\n(برای لغو /cancel را بزنید)")
    return GETTING_ADD_ADMIN_ID

async def process_add_admin_id(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        new_admin_id = int(update.message.text)
        current_admins = load_admins()
        if new_admin_id in current_admins:
            await update.message.reply_text("این کاربر در حال حاضر ادمین است.")
        else:
            current_admins.add(new_admin_id)
            save_admins(current_admins)
            await update.message.reply_text(f"✅ کاربر با شناسه `{new_admin_id}` با موفقیت به لیست ادمین‌ها اضافه شد.", parse_mode=ParseMode.MARKDOWN)
    except (IndexError, ValueError):
        await update.message.reply_text("خطا: شناسه وارد شده نامعتبر است. لطفا یک عدد صحیح وارد کنید.")
    return await admin_panel_command(update, context)

async def remove_admin_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    if not is_root_admin(query.from_user.id):
        await query.answer("⛔️ این دستور فقط توسط ادمین اصلی قابل استفاده است.", show_alert=True)
        return ADMIN_PANEL
    await query.answer()
    await query.message.edit_text("لطفا شناسه عددی (Chat ID) ادمینی که می‌خواهید حذف شود را وارد کنید.\n(برای لغو /cancel را بزنید)")
    return GETTING_REMOVE_ADMIN_ID

async def process_remove_admin_id(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        admin_to_remove = int(update.message.text)
        current_admins = load_admins()
        if admin_to_remove == ROOT_ADMIN_CHAT_ID:
            await update.message.reply_text("شما نمی‌توانید ادمین اصلی را حذف کنید.")
        elif admin_to_remove in current_admins:
            current_admins.remove(admin_to_remove)
            save_admins(current_admins)
            await update.message.reply_text(f"✅ کاربر با شناسه `{admin_to_remove}` از لیست ادمین‌ها حذف شد.", parse_mode=ParseMode.MARKDOWN)
        else:
            await update.message.reply_text("کاربری با این شناسه در لیست ادمین‌ها وجود ندارد.")
    except (IndexError, ValueError):
        await update.message.reply_text("خطا: شناسه وارد شده نامعتبر است. لطفا یک عدد صحیح وارد کنید.")
    return await admin_panel_command(update, context)

async def broadcast_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("لطفا پیامی که می‌خواهید برای همه کاربران ارسال شود را وارد کنید. (برای لغو /cancel را بزنید)")
    return GETTING_BROADCAST_MESSAGE

async def get_broadcast_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data['broadcast_message'] = update.message
    keyboard = [[
        InlineKeyboardButton("✅ ارسال پیام", callback_data="confirm_broadcast"),
        InlineKeyboardButton("❌ لغو", callback_data="cancel_broadcast")
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text("آیا از ارسال پیام زیر برای **تمام کاربران** اطمینان دارید؟")
    await update.message.reply_copy(update.effective_chat.id, update.message.id, reply_markup=reply_markup)
    return CONFIRM_BROADCAST

async def confirm_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    if query.data == "cancel_broadcast":
        await query.edit_message_text("ارسال پیام همگانی لغو شد.")
        return await admin_panel_command(update, context)

    message_to_send = context.user_data.get('broadcast_message')
    if not message_to_send:
        await query.edit_message_text("خطا: پیام یافت نشد. لطفاً دوباره تلاش کنید.")
        return await admin_panel_command(update, context)

    await query.edit_message_text("⏳ در حال ارسال پیام به تمام کاربران...")
    
    conn = get_db_connection()
    if not conn:
        await query.message.reply_text("خطای اتصال به دیتابیس.")
        return await admin_panel_command(update, context)

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT chat_id FROM telegram_users")
            users = cur.fetchall()
            
        success_count, fail_count = 0, 0
        for row in users:
            chat_id = row[0]
            try:
                await context.bot.copy_message(chat_id=chat_id, from_chat_id=message_to_send.chat_id, message_id=message_to_send.message_id)
                success_count += 1
            except Exception as e:
                logger.warning(f"Failed to send broadcast to {chat_id}: {e}")
                fail_count += 1
            await asyncio.sleep(BROADCAST_SLEEP_DELAY)
            
        await query.message.reply_text(f"✅ ارسال پیام همگانی به پایان رسید.\n\n- ارسال موفق: {success_count}\n- ارسال ناموفق: {fail_count}")
    finally:
        conn.close()

    context.user_data.pop('broadcast_message', None)
    return await admin_panel_command(update, context)

# --- Plan Management Handlers ---
async def manage_plans_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    keyboard = [
        [InlineKeyboardButton("افزودن پلن جدید ➕", callback_data="add_plan_start")],
        [InlineKeyboardButton("ویرایش یک پلن ✏️", callback_data="edit_plan_start")],
        [InlineKeyboardButton("حذف یک پلن ➖", callback_data="remove_plan_start")],
        [InlineKeyboardButton("مشاهده پلن‌های فعلی 📋", callback_data="view_plans")],
        [InlineKeyboardButton("بازگشت به پنل ادمین 🔙", callback_data="admin_panel_show")]
    ]
    text = "🛒 **مدیریت پلن‌های خرید**\n\nیک گزینه را انتخاب کنید:"
    await query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_MANAGE_PLANS

async def view_plans_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    global PLANS
    PLANS = load_plans()
    if not PLANS:
        plan_list_str = "در حال حاضر هیچ پلنی تعریف نشده است."
    else:
        plan_list_str = "\n".join(f"- {generate_plan_label(plan)}" for plan in PLANS.values())
    text = f"📋 **پلن‌های خرید فعلی**\n\n{plan_list_str}"
    keyboard = [[InlineKeyboardButton("بازگشت 🔙", callback_data="manage_plans_menu_show")]]
    await query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_MANAGE_PLANS

async def add_plan_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    context.user_data['new_plan'] = {}
    await query.message.edit_text("لطفا **تعداد توکن** برای پلن جدید را وارد کنید (مثلا: 10).\n(برای لغو /cancel را بزنید)")
    return GETTING_PLAN_TOKENS

async def get_plan_tokens(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        tokens = int(update.message.text)
        if tokens <= 0: raise ValueError
        context.user_data['new_plan']['tokens'] = tokens
        await update.message.reply_text("بسیار خب. حالا قیمت پلن را به **تومان** وارد کنید.\n(برای پلن فقط دلاری، `0` یا /skip را ارسال کنید)")
        return GETTING_PLAN_PRICE
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا یک عدد صحیح و مثبت وارد کنید.")
        return GETTING_PLAN_TOKENS

async def get_plan_price(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        text = update.message.text.strip()
        price = 0 if text.lower() == '/skip' else int(text)
        if price < 0: raise ValueError
        context.user_data['new_plan']['price'] = price
        await update.message.reply_text("و در آخر، قیمت را به **دلار** وارد کنید.\n(برای پلن فقط ریالی، `0` یا /skip را ارسال کنید)")
        return GETTING_PLAN_PRICE_USD
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا قیمت را به صورت یک عدد صحیح وارد کنید.")
        return GETTING_PLAN_PRICE

async def get_plan_price_usd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        text = update.message.text.strip()
        price_usd = 0.0 if text.lower() == '/skip' else float(text.replace(',', '.'))
        if price_usd < 0: raise ValueError
        new_plan = context.user_data['new_plan']
        new_plan['price_usd'] = price_usd

        if new_plan['price'] == 0 and new_plan['price_usd'] == 0:
            await update.message.reply_text("خطا: حداقل یکی از قیمت‌های تومانی یا دلاری باید مشخص شود. لطفا از ابتدا تلاش کنید.")
            context.user_data.pop('new_plan', None)
            return await manage_plans_menu(update, context)

        text = (f"**بررسی پلن جدید**\n\n"
                f"▪️ **نام پلن:** *{generate_plan_label(new_plan)}*\n\n"
                f"آیا اطلاعات فوق را تایید می‌کنید?")
        keyboard = [[InlineKeyboardButton("✅ بله، اضافه کن", callback_data="confirm_add_plan"), InlineKeyboardButton("❌ خیر، لغو کن", callback_data="manage_plans_menu_show")]]
        await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
        return ADMIN_MANAGE_PLANS
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا قیمت دلاری را به صورت یک عدد (مثلا 1.5 یا 2) وارد کنید.")
        return GETTING_PLAN_PRICE_USD

async def confirm_add_plan(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    new_plan = context.user_data.get('new_plan')
    if not new_plan:
        await query.answer("خطا: اطلاعات پلن یافت نشد.", show_alert=True)
        return await manage_plans_menu(update, context)
    
    current_plans = load_plans()
    plan_key = f"{new_plan['tokens']}_tokens_{str(uuid.uuid4())[:4]}"
    current_plans[plan_key] = new_plan
    save_plans(current_plans)
    
    await query.answer("✅ پلن با موفقیت اضافه شد.", show_alert=True)
    context.user_data.pop('new_plan', None)
    return await manage_plans_menu(update, context)

async def edit_plan_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    global PLANS
    PLANS = load_plans()
    if not PLANS:
        await query.message.edit_text("هیچ پلنی برای ویرایش وجود ندارد.", reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("بازگشت 🔙", callback_data="manage_plans_menu_show")]]))
        return ADMIN_MANAGE_PLANS

    keyboard = [[InlineKeyboardButton(f"✏️ {generate_plan_label(plan)}", callback_data=f"edit_plan:{key}")] for key, plan in PLANS.items()]
    keyboard.append([InlineKeyboardButton("بازگشت 🔙", callback_data="manage_plans_menu_show")])
    await query.message.edit_text("لطفا پلنی که می‌خواهید ویرایش شود را انتخاب کنید:", reply_markup=InlineKeyboardMarkup(keyboard))
    return EDITING_PLAN_SELECT

async def select_plan_to_edit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    plan_key = query.data.split(":")[1]
    if plan_key not in PLANS:
        await query.answer("این پلن دیگر وجود ندارد.", show_alert=True)
        return await manage_plans_menu(update, context)
    
    context.user_data['editing_plan'] = {'key': plan_key, 'original': PLANS[plan_key].copy()}
    await query.message.edit_text(
        f"در حال ویرایش پلن: *{generate_plan_label(PLANS[plan_key])}*\n\n"
        f"لطفا **تعداد توکن** جدید را وارد کنید.\n(برای لغو /cancel را بزنید)",
        parse_mode=ParseMode.MARKDOWN
    )
    return GETTING_NEW_PLAN_TOKENS

async def get_new_plan_tokens(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        tokens = int(update.message.text)
        if tokens <= 0: raise ValueError
        context.user_data['editing_plan']['tokens'] = tokens
        await update.message.reply_text("قیمت جدید به **تومان** را وارد کنید.\n(برای رد کردن `0` یا /skip را بزنید)")
        return GETTING_NEW_PLAN_PRICE
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا یک عدد صحیح و مثبت برای توکن وارد کنید.")
        return GETTING_NEW_PLAN_TOKENS

async def get_new_plan_price(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        text = update.message.text.strip()
        price = 0 if text.lower() == '/skip' else int(text)
        if price < 0: raise ValueError
        context.user_data['editing_plan']['price'] = price
        await update.message.reply_text("قیمت جدید به **دلار** را وارد کنید.\n(برای رد کردن `0` یا /skip را بزنید)")
        return GETTING_NEW_PLAN_PRICE_USD
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا یک عدد صحیح برای قیمت وارد کنید.")
        return GETTING_NEW_PLAN_PRICE

async def get_new_plan_price_usd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        text = update.message.text.strip()
        price_usd = 0.0 if text.lower() == '/skip' else float(text.replace(',', '.'))
        if price_usd < 0: raise ValueError
        context.user_data['editing_plan']['price_usd'] = price_usd

        if context.user_data['editing_plan']['price'] == 0 and price_usd == 0:
            await update.message.reply_text("خطا: حداقل یکی از قیمت‌های تومانی یا دلاری باید مشخص شود. لطفا از ابتدا تلاش کنید.")
            context.user_data.pop('editing_plan', None)
            return await manage_plans_menu(update, context)

        return await _show_plan_edit_confirmation(update, context)
    except (ValueError, TypeError):
        await update.message.reply_text("ورودی نامعتبر است. لطفا یک عدد برای قیمت دلاری وارد کنید.")
        return GETTING_NEW_PLAN_PRICE_USD

async def _show_plan_edit_confirmation(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    editing_data = context.user_data['editing_plan']
    original_plan = editing_data['original']
    
    text = (f"**تایید ویرایش پلن**\n\n"
            f"▪️ **پلن فعلی:** *{generate_plan_label(original_plan)}*\n\n"
            f"▪️ **پلن جدید:** *{generate_plan_label(editing_data)}*\n\n"
            "آیا تغییرات را تایید می‌کنید?")
    keyboard = [[
        InlineKeyboardButton("✅ بله، ذخیره کن", callback_data="confirm_edit_plan"),
        InlineKeyboardButton("❌ خیر، لغو کن", callback_data="manage_plans_menu_show")
    ]]
    await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_MANAGE_PLANS

async def confirm_plan_edit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    editing_data = context.user_data.get('editing_plan')
    if not editing_data:
        await query.answer("خطا: اطلاعات ویرایش یافت نشد.", show_alert=True)
        return await manage_plans_menu(update, context)
    
    current_plans = load_plans()
    plan_key = editing_data['key']
    current_plans[plan_key] = {
        'tokens': editing_data['tokens'], 
        'price': editing_data['price'], 
        'price_usd': editing_data['price_usd']
    }
    save_plans(current_plans)
    
    await query.answer("✅ پلن با موفقیت ویرایش و ذخیره شد.", show_alert=True)
    context.user_data.pop('editing_plan', None)
    return await manage_plans_menu(update, context)

async def remove_plan_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    global PLANS
    PLANS = load_plans()
    if not PLANS:
        await query.message.edit_text("هیچ پلنی برای حذف وجود ندارد.", reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("بازگشت 🔙", callback_data="manage_plans_menu_show")]]))
        return ADMIN_MANAGE_PLANS

    keyboard = [[InlineKeyboardButton(f"❌ {generate_plan_label(plan)}", callback_data=f"delete_plan:{key}")] for key, plan in PLANS.items()]
    keyboard.append([InlineKeyboardButton("بازگشت 🔙", callback_data="manage_plans_menu_show")])
    await query.message.edit_text("لطفا پلنی که می‌خواهید حذف شود را انتخاب کنید:", reply_markup=InlineKeyboardMarkup(keyboard))
    return REMOVING_PLAN

async def process_remove_plan(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    plan_key = query.data.split(":")[1]
    
    current_plans = load_plans()
    if plan_key in current_plans:
        del current_plans[plan_key]
        save_plans(current_plans)
        await query.answer("✅ پلن با موفقیت حذف شد.", show_alert=True)
    else:
        await query.answer("خطا: این پلن قبلا حذف شده است.", show_alert=True)

    return await manage_plans_menu(update, context)

# ===============================================================
# Payment Settings Handlers
# ===============================================================
async def manage_payment_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    settings = load_payment_settings()
    card_info = settings.get('card', {})
    paypal_info = settings.get('paypal', {})
    crypto_info = settings.get('crypto', {})

    crypto_str = "\n".join(f"  - `{addr}` ({coin})" for coin, addr in crypto_info.items()) if crypto_info else "  - تنظیم نشده"

    text = (
        f"💳 **تنظیمات روش‌های پرداخت**\n\n"
        f"**اطلاعات کارت:**\n"
        f"  - شماره: `{card_info.get('number', 'تنظیم نشده')}`\n"
        f"  - صاحب حساب: `{card_info.get('owner', 'تنظیم نشده')}`\n\n"
        f"**ایمیل پی‌پال:**\n"
        f"  - `{paypal_info.get('email', 'تنظیم نشده')}`\n\n"
        f"**آدرس‌های کریپتو:**\n{crypto_str}"
    )
    
    keyboard = [
        [InlineKeyboardButton("ویرایش اطلاعات کارت 💳", callback_data="edit_card_start")],
        [InlineKeyboardButton("ویرایش ایمیل پی‌پال 🅿️", callback_data="edit_paypal_start")],
        [InlineKeyboardButton("ویرایش آدرس کریپتو 💎", callback_data="edit_crypto_start")],
        [InlineKeyboardButton("بازگشت به پنل ادمین 🔙", callback_data="admin_panel_show")]
    ]
    
    await query.message.edit_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode=ParseMode.MARKDOWN)
    return ADMIN_MANAGE_PAYMENT

async def edit_card_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("لطفا **شماره کارت** جدید را وارد کنید.\n(برای لغو /cancel را بزنید)")
    return GETTING_CARD_NUMBER

async def get_card_number(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data['new_card_number'] = update.message.text
    await update.message.reply_text("حالا **نام صاحب کارت** را وارد کنید.\n(برای لغو /cancel را بزنید)")
    return GETTING_CARD_OWNER

async def get_card_owner(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    card_owner = update.message.text
    card_number = context.user_data.pop('new_card_number')
    
    settings = load_payment_settings()
    settings['card'] = {'number': card_number, 'owner': card_owner}
    save_payment_settings(settings)
    
    await update.message.reply_text("✅ اطلاعات کارت با موفقیت ذخیره شد.")
    return await admin_panel_command(update, context)

async def edit_paypal_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.message.edit_text("لطفا **ایمیل پی‌پال** جدید را وارد کنید.\n(برای لغو /cancel را بزنید)")
    return GETTING_PAYPAL_EMAIL

async def get_paypal_email(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    email = update.message.text
    
    settings = load_payment_settings()
    settings['paypal'] = {'email': email}
    save_payment_settings(settings)
    
    await update.message.reply_text("✅ ایمیل پی‌پال با موفقیت ذخیره شد.")
    return await admin_panel_command(update, context)
    
async def edit_crypto_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    await query.message.edit_text(
        "لطفا آدرس‌های جدید را با فرمت زیر وارد کنید (هر آدرس در یک خط):\n"
        "نام ارز:آدرس\n\n"
        "**مثال:**\n"
        "USDT (TRC20):TABC123\n"
        "BTC:bc1xyz789\n\n"
        "(برای لغو /cancel را بزنید)"
    )
    return GETTING_CRYPTO_ADDRESSES

async def get_crypto_addresses(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    try:
        lines = update.message.text.strip().split('\n')
        new_crypto_addresses = {}
        for line in lines:
            if ':' not in line: continue
            parts = line.split(':', 1)
            coin = parts[0].strip()
            address = parts[1].strip()
            if coin and address:
                new_crypto_addresses[coin] = address
        
        if not new_crypto_addresses:
            await update.message.reply_text("خطا: فرمت وارد شده صحیح نیست. هیچ آدرسی ذخیره نشد.")
        else:
            settings = load_payment_settings()
            settings['crypto'] = new_crypto_addresses
            save_payment_settings(settings)
            await update.message.reply_text("✅ آدرس‌های ارز دیجیتال با موفقیت ذخیره شدند.")

    except Exception as e:
        logger.error(f"Error parsing crypto addresses: {e}")
        await update.message.reply_text("خطا در پردازش اطلاعات. لطفا فرمت را بررسی کنید.")
        
    return await admin_panel_command(update, context)

# ===============================================================
# Support Ticket System (Refactored for SQL)
# ===============================================================
async def support_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user_email = context.user_data.get('user_email')
    if not user_email:
        await update.effective_message.reply_text(t('login_required_error', context))
        return ConversationHandler.END
    
    lang_code = context.user_data.get('language_code', 'fa')
    prompt_key = 'support_prompt_multilingual_warning' if lang_code not in ['fa', 'en'] else 'support_prompt'
    
    if update.callback_query: await update.callback_query.answer()
    await update.effective_message.reply_text(t(prompt_key, context))
    return GETTING_SUPPORT_MESSAGE

async def get_support_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    user_email = context.user_data.get('user_email')
    user_message = update.message.text
    ticket_id = str(uuid.uuid4()).split('-')[0].upper()
    
    conn = get_db_connection()
    if not conn:
        await update.message.reply_text(t('server_error', context))
        return ConversationHandler.END

    try:
        initial_history = json.dumps([{'sender': 'user', 'text': user_message, 'timestamp': str(datetime.now(timezone.utc))}])
        
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO support_tickets (ticket_id, user_email, user_chat_id, user_full_name, message_text, status, history)
                VALUES (%s, %s, %s, %s, %s, 'open', %s)
            """, (ticket_id, user_email, user.id, user.full_name, user_message, initial_history))
            conn.commit()

    except Exception as e:
        logger.error(f"Failed to save ticket {ticket_id}: {e}")
        await update.message.reply_text(t('server_error', context))
        return ConversationHandler.END
    finally:
        conn.close()

    # Admin Notifications
    admin_message_ids = {}
    admin_text = (f"📨 **تیکت پشتیبانی جدید**\n\n"
                  f"**از طرف:** {user.full_name}\n"
                  f"**ایمیل:** `{user_email}`\n"
                  f"**شناسه تیکت:** `{ticket_id}`\n\n"
                  f"**متن پیام:**\n{user_message}")
    keyboard = [[
        InlineKeyboardButton("پاسخ به کاربر 💬", callback_data=f"reply_ticket:{ticket_id}"),
        InlineKeyboardButton("بستن تیکت ✅", callback_data=f"close_ticket:{ticket_id}")
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)

    for admin_id in admin_ids:
        try:
            msg = await context.bot.send_message(
                chat_id=admin_id, text=admin_text, parse_mode=ParseMode.MARKDOWN, reply_markup=reply_markup
            )
            admin_message_ids[str(admin_id)] = msg.message_id
        except Exception as e:
            logger.error(f"Failed to send support ticket {ticket_id} to admin {admin_id}: {e}")

    # Update admin message IDs in DB
    if admin_message_ids:
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("UPDATE support_tickets SET admin_message_ids = %s WHERE ticket_id = %s", 
                                (json.dumps(admin_message_ids), ticket_id))
                    conn.commit()
            finally:
                conn.close()

    await update.message.reply_text(t('ticket_sent_success', context, ticket_id=ticket_id), parse_mode=ParseMode.MARKDOWN)
    return await show_main_menu(update, context)

async def reply_to_ticket_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    if not is_admin(query.from_user.id):
        await query.answer("⛔️ شما دسترسی لازم برای این کار را ندارید.", show_alert=True)
        return ConversationHandler.END
        
    await query.answer()
    ticket_id = query.data.split(":")[1]
    admin_name = query.from_user.full_name
    
    conn = get_db_connection()
    if not conn:
        await query.message.reply_text("Database Error.")
        return ConversationHandler.END
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM support_tickets WHERE ticket_id = %s", (ticket_id,))
            ticket_data = cur.fetchone()
            
            if not ticket_data:
                await query.edit_message_text(f"خطا: تیکت `{ticket_id}` یافت نشد.", parse_mode=ParseMode.MARKDOWN)
                return ConversationHandler.END
            
            if ticket_data['status'] != 'open':
                await query.answer(f"این تیکت قبلاً توسط ادمین دیگری در حال بررسی یا بسته شده است.", show_alert=True)
                return ADMIN_PANEL

            # Lock the ticket
            cur.execute("UPDATE support_tickets SET status = %s WHERE ticket_id = %s", (f'processing by {admin_name}', ticket_id))
            conn.commit()

        context.user_data['ticket_id_to_reply'] = ticket_id
        
        # Update Admin messages UI to show locking
        original_base_text = (f"📨 **تیکت پشتیبانی جدید**\n\n"
                              f"**از طرف:** {ticket_data.get('user_full_name')}\n"
                              f"**ایمیل:** `{ticket_data.get('user_email')}`\n"
                              f"**شناسه تیکت:** `{ticket_id}`\n\n"
                              f"**متن پیام:**\n{ticket_data.get('message_text')}")

        admin_message_ids = ticket_data.get('admin_message_ids', {})
        for admin_id_str, message_id in admin_message_ids.items():
            status_text = original_base_text
            if int(admin_id_str) != query.from_user.id:
                status_text += f"\n\n---\n*⏳ در حال پاسخ توسط {admin_name}...*"
            try:
                await context.bot.edit_message_text(
                    text=status_text, chat_id=int(admin_id_str), message_id=message_id,
                    reply_markup=None, parse_mode=ParseMode.MARKDOWN
                )
            except Exception as e:
                logger.warning(f"Could not edit admin message: {e}")

        await query.message.reply_text(
            f"در حال پاسخ به تیکت `{ticket_id}`.\n"
            "لطفا پیام خود را وارد کنید. (برای لغو /cancel را بزنید)",
            parse_mode=ParseMode.MARKDOWN
        )
        return ADMIN_REPLYING

    finally:
        conn.close()

async def cancel_admin_reply(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    admin_name = update.effective_user.full_name
    ticket_id = context.user_data.get('ticket_id_to_reply')

    if ticket_id:
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    # Unlock ticket
                    cur.execute("UPDATE support_tickets SET status = 'open' WHERE ticket_id = %s", (ticket_id,))
                    conn.commit()
                    cur.execute("SELECT * FROM support_tickets WHERE ticket_id = %s", (ticket_id,))
                    data = cur.fetchone()
                    
                    if data:
                        admin_message_ids = data.get('admin_message_ids', {})
                        original_text = (f"📨 **تیکت پشتیبانی جدید**\n\n"
                                         f"**از طرف:** {data.get('user_full_name')}\n"
                                         f"**ایمیل:** `{data.get('user_email')}`\n"
                                         f"**شناسه تیکت:** `{ticket_id}`\n\n"
                                         f"**متن پیام:**\n{data.get('message_text')}")
                        
                        original_keyboard = InlineKeyboardMarkup([[
                            InlineKeyboardButton("پاسخ به کاربر 💬", callback_data=f"reply_ticket:{ticket_id}"),
                            InlineKeyboardButton("بستن تیکت ✅", callback_data=f"close_ticket:{ticket_id}")
                        ]])

                        for admin_id_str, message_id in admin_message_ids.items():
                            try:
                                await context.bot.edit_message_text(
                                    text=original_text, chat_id=int(admin_id_str), message_id=message_id,
                                    reply_markup=original_keyboard, parse_mode=ParseMode.MARKDOWN
                                )
                            except: pass
            finally:
                conn.close()
    
    context.user_data.pop('ticket_id_to_reply', None)
    await update.message.reply_text("پاسخ به تیکت لغو شد.")
    await admin_panel_command(update, context)
    return ConversationHandler.END

async def send_reply_to_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    admin = update.effective_user
    reply_text = update.message.text
    ticket_id = context.user_data.get('ticket_id_to_reply')

    if not ticket_id:
        await update.message.reply_text("خطا: شناسه تیکت یافت نشد.")
        return ConversationHandler.END

    conn = get_db_connection()
    if not conn: return ConversationHandler.END

    try:
        new_history_item = {'sender': 'admin', 'admin_name': admin.full_name, 'text': reply_text, 'timestamp': str(datetime.now(timezone.utc))}
        
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Append to history JSONB array
            cur.execute("""
                UPDATE support_tickets 
                SET history = history || %s::jsonb, status = 'open'
                WHERE ticket_id = %s
                RETURNING *
            """, (json.dumps([new_history_item]), ticket_id))
            conn.commit()
            ticket_data = cur.fetchone()

        user_chat_id = ticket_data.get('user_chat_id')
        user_email = ticket_data.get('user_email')
        
        # Get user lang
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT language_code FROM users WHERE email = %s", (user_email,))
            user_res = cur.fetchone()
            user_lang = user_res['language_code'] if user_res else 'fa'

        user_message = t_for_user('ticket_reply_header', user_lang, ticket_id=ticket_id) + f"\n\n{reply_text}"
        keyboard = [[
            InlineKeyboardButton(t_for_user('ticket_continue_conversation', user_lang), callback_data=f"continue_ticket:{ticket_id}"),
            InlineKeyboardButton(t_for_user('ticket_issue_resolved', user_lang), callback_data=f"user_close_ticket:{ticket_id}")
        ]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await context.bot.send_message(chat_id=user_chat_id, text=user_message, parse_mode=ParseMode.MARKDOWN, reply_markup=reply_markup)

        # Restore admin UI
        original_text = (f"📨 **تیکت پشتیبانی جدید**\n\n"
                         f"**از طرف:** {ticket_data.get('user_full_name')}\n"
                         f"**ایمیل:** `{ticket_data.get('user_email')}`\n"
                         f"**شناسه تیکت:** `{ticket_id}`\n\n"
                         f"**متن پیام:**\n{ticket_data.get('message_text')}")
        
        original_keyboard = InlineKeyboardMarkup([[
            InlineKeyboardButton("پاسخ به کاربر 💬", callback_data=f"reply_ticket:{ticket_id}"),
            InlineKeyboardButton("بستن تیکت ✅", callback_data=f"close_ticket:{ticket_id}")
        ]])
        
        admin_message_ids = ticket_data.get('admin_message_ids', {})
        for admin_id_str, message_id in admin_message_ids.items():
            try:
                await context.bot.edit_message_text(
                    text=original_text, chat_id=int(admin_id_str), message_id=message_id,
                    reply_markup=original_keyboard, parse_mode=ParseMode.MARKDOWN)
            except: pass

        await update.message.reply_text(f"✅ پاسخ شما برای کاربر ارسال شد.")
    
    except Exception as e:
        logger.error(f"Error sending reply: {e}")
        await update.message.reply_text("خطایی رخ داد.")
    finally:
        conn.close()
    
    context.user_data.pop('ticket_id_to_reply', None)
    await admin_panel_command(update, context)
    return ConversationHandler.END

async def continue_ticket_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    ticket_id = query.data.split(":")[1]
    context.user_data['replying_to_ticket_id'] = ticket_id

    await query.message.edit_text(
        t('ticket_reply_prompt', context, ticket_id=ticket_id),
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=None
    )
    return USER_REPLYING_TO_TICKET

async def forward_user_reply_to_admins(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user = update.effective_user
    reply_text = update.message.text
    ticket_id = context.user_data.get('replying_to_ticket_id')

    conn = get_db_connection()
    if not conn: return ConversationHandler.END

    try:
        new_history_item = {'sender': 'user', 'text': reply_text, 'timestamp': str(datetime.now(timezone.utc))}
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE support_tickets 
                SET history = history || %s::jsonb, status = 'open'
                WHERE ticket_id = %s
            """, (json.dumps([new_history_item]), ticket_id))
            conn.commit()
        
        admin_text = (f"📣 **پاسخ جدید از کاربر**\n\n"
                      f"**برای تیکت:** `{ticket_id}`\n"
                      f"**از طرف:** {user.full_name}\n\n"
                      f"**متن پیام:**\n{reply_text}")
        keyboard = [[
            InlineKeyboardButton("پاسخ به کاربر 💬", callback_data=f"reply_ticket:{ticket_id}"),
            InlineKeyboardButton("بستن تیکت ✅", callback_data=f"close_ticket:{ticket_id}")
        ]]
        reply_markup = InlineKeyboardMarkup(keyboard)

        for admin_id in admin_ids:
            try:
                await context.bot.send_message(chat_id=admin_id, text=admin_text, parse_mode=ParseMode.MARKDOWN, reply_markup=reply_markup)
            except Exception as e:
                logger.error(f"Failed to forward user reply to admin {admin_id}: {e}")
        
        await update.message.reply_text(t('ticket_reply_sent', context))
    finally:
        conn.close()

    context.user_data.pop('replying_to_ticket_id', None)
    return await show_main_menu(update, context)

async def _close_ticket_logic(context: ContextTypes.DEFAULT_TYPE, ticket_id: str, closed_by: str, query: Update.callback_query = None):
    conn = get_db_connection()
    if not conn: return

    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM support_tickets WHERE ticket_id = %s", (ticket_id,))
            ticket_data = cur.fetchone()
            
            if not ticket_data:
                if query: await query.edit_message_text(f"خطا: تیکت یافت نشد.")
                return

            if ticket_data['status'] == 'closed':
                if query: await query.answer("این تیکت قبلا بسته شده است.", show_alert=True)
                return

            cur.execute("UPDATE support_tickets SET status = 'closed', closed_by = %s, closed_at = NOW() WHERE ticket_id = %s", (closed_by, ticket_id))
            conn.commit()

        notification_text = f"ℹ️ تیکت `{ticket_id}` توسط **{closed_by}** بسته شد."
        closing_entity_id = query.from_user.id if query else None

        for admin_id in admin_ids:
            if admin_id != closing_entity_id:
                try:
                    await context.bot.send_message(chat_id=admin_id, text=notification_text, parse_mode=ParseMode.MARKDOWN)
                except: pass

        user_chat_id = ticket_data.get('user_chat_id')
        user_email = ticket_data.get('user_email')
        
        if user_chat_id and closing_entity_id != user_chat_id:
            # Get user lang
            with conn.cursor() as cur:
                cur.execute("SELECT language_code FROM users WHERE email = %s", (user_email,))
                res = cur.fetchone()
                user_lang = res[0] if res else 'fa'
            
            user_notification = t_for_user('ticket_closed_by_support', user_lang, ticket_id=ticket_id)
            await context.bot.send_message(chat_id=user_chat_id, text=user_notification, parse_mode=ParseMode.MARKDOWN)

        admin_message_ids = ticket_data.get('admin_message_ids', {})
        for admin_id_str, message_id in admin_message_ids.items():
            try:
                original_full_text = (f"📨 **تیکت پشتیبانی جدید**\n\n"
                                      f"**از طرف:** {ticket_data.get('user_full_name')}\n"
                                      f"**ایمیل:** `{user_email}`\n"
                                      f"**شناسه تیکت:** `{ticket_id}`\n\n"
                                      f"**متن پیام:**\n{ticket_data.get('message_text')}")
                final_admin_text = original_full_text + f"\n\n---\n*✅ این تیکت توسط {closed_by} بسته شد.*"
                
                await context.bot.edit_message_text(
                    text=final_admin_text, chat_id=int(admin_id_str), message_id=message_id,
                    parse_mode=ParseMode.MARKDOWN, reply_markup=None
                )
            except: pass
    except Exception as e:
        logger.error(f"Error closing ticket: {e}")
    finally:
        conn.close()

async def close_ticket_admin(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    if not is_admin(query.from_user.id):
        await query.answer("⛔️ دسترسی ندارید.", show_alert=True)
        return
    await query.answer("در حال بستن تیکت...")
    ticket_id = query.data.split(":")[1]
    await _close_ticket_logic(context, ticket_id, query.from_user.full_name, query)

async def close_ticket_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer(t('ticket_closing', context))
    ticket_id = query.data.split(":")[1]
    
    await _close_ticket_logic(context, ticket_id, t('user_entity', context), query)

    await query.message.edit_text(
        t('ticket_closed_by_user', context, ticket_id=ticket_id),
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=None
    )
    await asyncio.sleep(2)
    return await show_main_menu(update, context)

# ===============================================================
# Main User Conversation (SQL Auth - Adjusted for Backend Schema)
# ===============================================================

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.clear()
    keyboard = [[InlineKeyboardButton(text, callback_data=f"lang_{code}")] for code, text in SUPPORTED_LANGUAGES.items()]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.effective_message.reply_text(
        "Welcome! Please select your language.\n\n"
        "خوش آمدید! لطفا زبان خود را انتخاب کنید.",
        reply_markup=reply_markup
    )
    return SELECTING_LANGUAGE

async def set_language(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    lang_code = query.data.split("_")[1]
    context.user_data['language_code'] = lang_code

    await query.message.edit_text(t('enter_email_prompt', context), parse_mode=ParseMode.MARKDOWN)
    return GETTING_EMAIL
        
async def get_email(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user_email = update.message.text.lower().strip()
    
    # --- استفاده از تابع اعتبارسنجی جدید ---
    is_valid, error_msg = validate_email_deep(user_email)
    
    if not is_valid:
        await update.message.reply_text(f"❌ {error_msg}")
        return GETTING_EMAIL
    
    context.user_data['user_email'] = user_email
    user = update.effective_user
    
    conn = get_db_connection()
    if not conn:
        await update.message.reply_text(t('server_error', context))
        return ConversationHandler.END

    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Check if user exists in the main 'users' table
            cur.execute("SELECT * FROM users WHERE email = %s", (user_email,))
            db_user = cur.fetchone()

        if db_user:
            # User exists, now check/update the telegram link in 'telegram_users'
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("SELECT * FROM telegram_users WHERE email = %s", (user_email,))
                tg_user = cur.fetchone()
                
                if tg_user:
                    # If chat_id changed, update it
                    if tg_user['chat_id'] != user.id:
                        cur.execute("UPDATE telegram_users SET chat_id = %s WHERE email = %s", (user.id, user_email))
                else:
                    # Link doesn't exist yet, insert it
                    cur.execute("INSERT INTO telegram_users (email, chat_id) VALUES (%s, %s)", (user_email, user.id))
                
                conn.commit()
            
            # Show password prompt with "Forgot Password" button
            keyboard = [[InlineKeyboardButton("فراموشی رمز عبور 🔒", callback_data="forgot_password_start")]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            await update.message.reply_text("لطفا رمز عبور خود را وارد کنید:", reply_markup=reply_markup)
            
            return GETTING_PASSWORD
        else:
            # User does not exist, start registration
            contact_keyboard = KeyboardButton(text=t('share_contact_button', context), request_contact=True)
            reply_markup = ReplyKeyboardMarkup([[contact_keyboard]], one_time_keyboard=True, resize_keyboard=True)
            await update.message.reply_text(t('ask_for_phone', context), reply_markup=reply_markup, parse_mode=ParseMode.MARKDOWN)
            return GETTING_PHONE

    except Exception as e:
        logger.error(f"Error in get_email: {e}")
        logger.error(traceback.format_exc())
        await update.message.reply_text(t('server_error', context))
        return ConversationHandler.END
    finally:
        conn.close()

# --- Password Reset Handlers ---
async def forgot_password_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    user_email = context.user_data.get('user_email')
    if user_email:
        # If we already have the email in context (Logged in or just entered email), skip re-asking
        await query.message.reply_text(f"بازیابی رمز عبور برای ایمیل `{user_email}`\nآیا تایید می‌کنید؟", 
                                       parse_mode=ParseMode.MARKDOWN,
                                       reply_markup=InlineKeyboardMarkup([[
                                           InlineKeyboardButton("✅ بله، ادامه", callback_data="confirm_reset_email"),
                                           InlineKeyboardButton("❌ خیر، تغییر ایمیل", callback_data="change_reset_email")
                                       ]]))
        return RESET_GET_EMAIL
    else:
        await query.message.reply_text("لطفا ایمیلی که با آن ثبت نام کرده‌اید را برای بازنشانی رمز عبور وارد کنید.\n(برای لغو /cancel را بزنید)")
        return RESET_GET_EMAIL

async def confirm_reset_logic(update: Update, context: ContextTypes.DEFAULT_TYPE, email: str) -> int:
    user_id = update.effective_user.id
    conn = get_db_connection()
    if not conn: return ConversationHandler.END

    try:
        # Check user existence
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM users WHERE email = %s", (email,))
            user = cur.fetchone()

        if not user:
            await update.effective_message.reply_text("کاربری با این ایمیل یافت نشد.")
            return RESET_GET_EMAIL
        
        # Security Check: Use telegram_users table for verification
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT chat_id FROM telegram_users WHERE email = %s", (email,))
            tg_data = cur.fetchone()
        
        if not tg_data or tg_data['chat_id'] != user_id:
            await update.effective_message.reply_text(
                "⛔️ **خطای امنیتی**\n\n"
                "امکان بازنشانی رمز عبور برای این ایمیل از طریق این حساب تلگرام وجود ندارد.\n"
                "لطفا با همان اکانت تلگرامی که ثبت‌نام کرده‌اید تلاش کنید.",
                parse_mode=ParseMode.MARKDOWN
            )
            return ConversationHandler.END

        context.user_data['reset_email'] = email
        await update.effective_message.reply_text("✅ هویت شما تایید شد.\nلطفا **رمز عبور جدید** خود را وارد کنید:")
        return RESET_NEW_PASSWORD

    except Exception as e:
        logger.error(f"Reset error: {e}")
        await update.effective_message.reply_text(t('server_error', context))
        return ConversationHandler.END
    finally:
        conn.close()

async def reset_get_email(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    # Handle callback from "confirm_reset_email"
    if update.callback_query:
        query = update.callback_query
        await query.answer()
        if query.data == "confirm_reset_email":
            email = context.user_data.get('user_email')
            return await confirm_reset_logic(update, context, email)
        elif query.data == "change_reset_email":
            await query.message.edit_text("لطفا ایمیل صحیح را وارد کنید:")
            return RESET_GET_EMAIL

    email = update.message.text.lower().strip()
    if not is_valid_email_syntax(email):
        await update.message.reply_text(t('invalid_email_format', context))
        return RESET_GET_EMAIL
        
    return await confirm_reset_logic(update, context, email)

async def reset_new_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    new_password = update.message.text
    email = context.user_data.get('reset_email')
    
    if len(new_password) < 6:
        await update.message.reply_text(t('password_too_short', context))
        return RESET_NEW_PASSWORD

    conn = get_db_connection()
    if not conn: return ConversationHandler.END

    try:
        new_hash = generate_password_hash(new_password)
        with conn.cursor() as cur:
            # Update password AND ensure account is verified (since they are resetting via authorized Telegram)
            # IMPORTANT: Do NOT add tokens here.
            cur.execute("""
                UPDATE users 
                SET password_hash = %s, is_verified = TRUE, verification_token = NULL
                WHERE email = %s
            """, (new_hash, email))
            conn.commit()
        
        await update.message.reply_text("✅ رمز عبور شما با موفقیت تغییر کرد.\nاکنون وارد منوی اصلی می‌شوید.")
        
        # Log them in automatically
        context.user_data['user_email'] = email
        context.user_data['is_logged_in'] = True
        return await show_main_menu(update, context)

    except Exception as e:
        logger.error(f"Reset password update error: {e}")
        await update.message.reply_text(t('server_error', context))
        return ConversationHandler.END
    finally:
        conn.close()

# -------------------------------

async def get_phone(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    contact = update.message.contact
    user = update.effective_user

    if not contact or contact.user_id != user.id:
        await update.message.reply_text(t('invalid_contact_share', context))
        return GETTING_PHONE

    phone_number = contact.phone_number
    if not phone_number.startswith('+'): phone_number = f"+{phone_number}"
    context.user_data['phone_number'] = phone_number

    # Check phone uniqueness
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM users WHERE phone_number = %s", (phone_number,))
            if cur.fetchone():
                await update.message.reply_text(t('phone_already_exists', context), reply_markup=ReplyKeyboardRemove())
                return await start(update, context)
    finally:
        if conn: conn.close()
        
    await update.message.reply_text(t('ask_for_password', context), reply_markup=ReplyKeyboardRemove(), parse_mode=ParseMode.MARKDOWN)
    return GETTING_PASSWORD

async def get_password(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    password = update.message.text
    
    # Check if user is logging in or registering
    is_registration = 'phone_number' in context.user_data
    conn = get_db_connection()
    
    if is_registration:
        if len(password) < 6:
            await update.message.reply_text(t('password_too_short', context))
            return GETTING_PASSWORD

        email = context.user_data['user_email']
        user = update.effective_user
        phone_number = context.user_data['phone_number']
        lang_code = context.user_data.get('language_code', 'fa')

        if not conn:
            await update.message.reply_text(t('server_error', context))
            return ConversationHandler.END

        try:
            password_hash = generate_password_hash(password)
            # Generate UUID suitable for backend cookie
            new_uid = str(uuid.uuid4())
            
            with conn.cursor() as cur:
                # 1. Insert into users (main table)
                # IMPORTANT: is_verified = TRUE (Verified by Telegram Phone)
                # IMPORTANT: tokens = 5 (Bonus for new registration)
                cur.execute("""
                    INSERT INTO users (uid, email, password_hash, display_name, phone_number, language_code, tokens, is_verified, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, 5, TRUE, NOW())
                """, (new_uid, email, password_hash, user.full_name, phone_number, lang_code))
                
                # 2. Insert into telegram_users (link table)
                cur.execute("""
                    INSERT INTO telegram_users (email, chat_id)
                    VALUES (%s, %s)
                """, (email, user.id))
                
                conn.commit()

            message_text = t('registration_success', context, token_count=5)
            # No need for activation link anymore as we set is_verified=TRUE
            await update.message.reply_text(f"✅ ثبت‌نام شما با موفقیت انجام شد.\n\n🎉 **۵ توکن هدیه** به حساب شما افزوده شد.\nحساب شما تایید شده و آماده استفاده است.", parse_mode=ParseMode.MARKDOWN)
            
            context.user_data['is_logged_in'] = True
            return await show_main_menu(update, context)
        except psycopg2.IntegrityError:
            conn.rollback()
            await update.message.reply_text(t('email_already_exists', context))
            return await start(update, context)
        except Exception as e:
            logger.error(f"Failed to create user {email}: {e}")
            logger.error(traceback.format_exc())
            await update.message.reply_text(t('server_error', context))
            return ConversationHandler.END
        finally:
            conn.close()
    else:
        # Login Logic
        user_email = context.user_data.get('user_email')
        if not conn: return ConversationHandler.END
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("SELECT password_hash FROM users WHERE email = %s", (user_email,))
                res = cur.fetchone()
                
            if res and check_password_hash(res['password_hash'], password):
                context.user_data['is_logged_in'] = True
                await update.message.reply_text(t('login_successful', context))
                return await show_main_menu(update, context)
            else:
                # Wrong password
                keyboard = [[InlineKeyboardButton("فراموشی رمز عبور 🔒", callback_data="forgot_password_start")]]
                reply_markup = InlineKeyboardMarkup(keyboard)
                await update.message.reply_text("❌ رمز عبور اشتباه است.\nلطفا دوباره تلاش کنید یا از گزینه فراموشی رمز استفاده کنید:", reply_markup=reply_markup)
                return GETTING_PASSWORD
        finally:
            conn.close()

async def show_main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    user_email = context.user_data.get('user_email')
    user_id = update.effective_user.id
    if not user_email: return await start(update, context)

    token_count = "N/A"
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT tokens FROM users WHERE email = %s", (user_email,))
                res = cur.fetchone()
                if res: token_count = res[0]
        except Exception: pass
        finally: conn.close()

    text = t('main_menu_text', context, email=user_email, token_count=token_count)
    # Using t() for the new button instead of hardcoded string
    keyboard = [
        [InlineKeyboardButton(t('check_tokens_button', context), callback_data="check_tokens")],
        [InlineKeyboardButton(t('buy_tokens_button', context), callback_data="buy_tokens")],
        [InlineKeyboardButton(t('support_button', context), callback_data="support")],
        [InlineKeyboardButton(t('change_password_button', context), callback_data="change_password_start")],
    ]
    if is_admin(user_id):
        keyboard.append([InlineKeyboardButton("⚙️ پنل ادمین", callback_data="admin_panel_show")])
    keyboard.append([InlineKeyboardButton(t('logout_button', context), callback_data="logout")])
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    if update.callback_query:
        await update.callback_query.answer()
        try:
            await update.callback_query.message.edit_text(text, reply_markup=reply_markup, parse_mode=ParseMode.MARKDOWN)
        except BadRequest as e:
            if "message is not modified" not in str(e): raise e
    else:
        await update.effective_message.reply_text(text, reply_markup=reply_markup, parse_mode=ParseMode.MARKDOWN)
    
    return MAIN_MENU

async def check_tokens_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    return await show_main_menu(update, context)

async def show_payment_methods(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    
    lang_code = context.user_data.get('language_code', 'fa')
    keyboard = []
    
    if lang_code == 'fa':
        keyboard.append([InlineKeyboardButton(t('pay_with_card_button', context), callback_data="pay_card")])
    else:
        keyboard.extend([
            [InlineKeyboardButton(t('pay_with_paypal_button', context), callback_data="pay_paypal")],
            [InlineKeyboardButton(t('pay_with_crypto_button', context), callback_data="pay_crypto")]
        ])
    
    keyboard.append([InlineKeyboardButton(t('back_button', context), callback_data="start_menu")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.message.edit_text(t('choose_payment_method', context), reply_markup=reply_markup)
    return CHOOSING_PAYMENT_METHOD

async def show_plan_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    payment_method = query.data.split('_')[1]
    context.user_data['payment_method'] = payment_method

    keyboard = []
    for key, plan in PLANS.items():
        if payment_method == 'card':
            if plan.get('price', 0) > 0:
                price_str = format_price_toman(plan['price'])
                label = f"{plan.get('tokens',0)} توکن - {price_str}"
                keyboard.append([InlineKeyboardButton(label, callback_data=f"plan_{key}")])
        else: # paypal or crypto
            if plan.get('price_usd', 0) > 0:
                price_str = f"${plan.get('price_usd', 0.0):.2f}"
                label = f"{plan.get('tokens',0)} Tokens - {price_str}"
                keyboard.append([InlineKeyboardButton(label, callback_data=f"plan_{key}")])

    keyboard.append([InlineKeyboardButton(t('back_button', context), callback_data="back_to_payment_methods")])
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.message.edit_text(t('choose_purchase_plan', context), reply_markup=reply_markup)
    return CHOOSING_PLAN

async def select_plan(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    plan_key = query.data.replace("plan_", "")
    context.user_data["selected_plan"] = plan_key
    payment_method = context.user_data.get('payment_method')
    user_email = context.user_data.get("user_email")

    if plan_key not in PLANS or not payment_method:
        await query.message.edit_text(t('plan_not_found_error', context))
        return await show_main_menu(update, context)

    plan = PLANS[plan_key]
    settings = load_payment_settings()
    
    if payment_method == 'card':
        price_display = format_price_toman(plan['price'])
        plan_label = f"{plan['tokens']} توکن"
        card_details = settings.get('card', {})
        text = t('payment_details_card', context, plan_label=plan_label, price=price_display, card_number=card_details.get('number', 'N/A'), card_owner=card_details.get('owner', 'N/A'))
    else: # paypal or crypto
        price_display = f"${plan['price_usd']:.2f} USD"
        plan_label = f"{plan['tokens']} Tokens"
        if payment_method == 'paypal':
            paypal_details = settings.get('paypal', {})
            text = t('payment_details_paypal', context, plan_label=plan_label, price=price_display, paypal_email=paypal_details.get('email', 'N/A'), email=user_email)
        else: # crypto
            crypto_details = settings.get('crypto', {})
            wallets = "\n".join([f"- `{addr}` ({coin})" for coin, addr in crypto_details.items()])
            text = t('payment_details_crypto', context, plan_label=plan_label, price=price_display, wallets=wallets)
    
    await query.message.edit_text(text, parse_mode=ParseMode.MARKDOWN)
    await query.message.reply_text(t('awaiting_receipt_instructions', context), parse_mode=ParseMode.MARKDOWN)
    return WAITING_FOR_RECEIPT

async def handle_receipt(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not update.message.photo:
        await update.message.reply_text(t('invalid_receipt_format', context), parse_mode=ParseMode.MARKDOWN)
        return WAITING_FOR_RECEIPT

    photo = update.message.photo[-1]
    user = update.effective_user
    plan_key = context.user_data.get("selected_plan")
    user_email = context.user_data.get("user_email")
    payment_method = context.user_data.get("payment_method", "نامشخص")

    if not all([plan_key, user_email, plan_key in PLANS]):
        await update.message.reply_text(t('purchase_info_error', context))
        return ConversationHandler.END

    plan = PLANS[plan_key]
    tracking_code = str(uuid.uuid4()).split('-')[0].upper()
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO purchase_orders (tracking_code, user_email, user_full_name, user_chat_id, plan_key, status, payment_method)
                    VALUES (%s, %s, %s, %s, %s, 'pending', %s)
                """, (tracking_code, user_email, user.full_name, user.id, plan_key, payment_method))
                conn.commit()
        except Exception as e:
            logger.error(f"Failed to create order: {e}")
            await update.message.reply_text(t('server_error', context))
            return ConversationHandler.END
        finally:
            conn.close()

    admin_caption = (f"✅ **سفارش جدید**\n\n"
                     f"**کد پیگیری:** `{tracking_code}`\n"
                     f"**نام کاربر:** {user.full_name}\n"
                     f"**ایمیل:** `{user_email}`\n"
                     f"**پلن:** {generate_plan_label(plan)}\n"
                     f"**روش پرداخت:** {payment_method.capitalize()}")
    keyboard = [[
        InlineKeyboardButton("✅ تایید سفارش", callback_data=f"confirm:{tracking_code}"),
        InlineKeyboardButton("❌ رد سفارش", callback_data=f"reject:{tracking_code}")
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)

    admin_message_ids = {}
    for admin_id in admin_ids:
        try:
            msg = await context.bot.send_photo(chat_id=admin_id, photo=photo.file_id, caption=admin_caption, parse_mode=ParseMode.MARKDOWN, reply_markup=reply_markup)
            admin_message_ids[str(admin_id)] = msg.message_id
        except Exception as e:
            logger.error(f"Failed to send receipt to admin {admin_id}: {e}")
    
    if admin_message_ids:
        conn = get_db_connection()
        if conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE purchase_orders SET admin_message_ids = %s WHERE tracking_code = %s", (json.dumps(admin_message_ids), tracking_code))
                conn.commit()
            conn.close()

    await update.message.reply_text(t('receipt_sent_success', context, tracking_code=tracking_code), parse_mode=ParseMode.MARKDOWN)
    return await show_main_menu(update, context)

async def handle_admin_decision(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    if not is_admin(update.effective_user.id):
        await query.answer("⛔️ دسترسی ندارید.", show_alert=True)
        return
    
    await query.answer()
    
    action, tracking_code = query.data.split(":")
    admin_name = query.from_user.full_name
    conn = get_db_connection()
    if not conn: return

    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM purchase_orders WHERE tracking_code = %s", (tracking_code,))
            order_data = cur.fetchone()

            if not order_data:
                await query.edit_message_caption(caption=f"خطا: سفارش یافت نشد.")
                return

            if order_data['status'] != 'pending':
                processed_by = order_data.get('processed_by', 'دیگران')
                await query.answer(f"قبلاً توسط {processed_by} بررسی شده است.", show_alert=True)
                return

            target_email = order_data['user_email']
            tokens_to_add = 0
            new_status = ""
            user_notification_key = ""

            if action == "confirm":
                plan_key = order_data['plan_key']
                if plan_key not in PLANS:
                    await query.message.reply_text(f"خطا: پلن دیگر وجود ندارد.")
                    return

                tokens_to_add = PLANS[plan_key]['tokens']
                cur.execute("UPDATE users SET tokens = tokens + %s WHERE email = %s", (tokens_to_add, target_email))
                new_status = 'confirmed'
                user_notification_key = 'order_confirmed'
            else:
                new_status = 'rejected'
                user_notification_key = 'order_rejected'
            
            cur.execute("UPDATE purchase_orders SET status = %s, processed_by = %s WHERE tracking_code = %s", (new_status, admin_name, tracking_code))
            conn.commit()

            # Notify user
            # Need to get chat_id from telegram_users table now
            cur.execute("SELECT chat_id FROM telegram_users WHERE email = %s", (target_email,))
            tg_user = cur.fetchone()
            cur.execute("SELECT language_code FROM users WHERE email = %s", (target_email,))
            user_meta = cur.fetchone()
            
            if tg_user:
                lang_code = user_meta['language_code'] if user_meta else 'fa'
                notification_text = t_for_user(user_notification_key, lang_code, tracking_code=tracking_code, token_count=tokens_to_add)
                await context.bot.send_message(chat_id=tg_user['chat_id'], text=notification_text, parse_mode=ParseMode.MARKDOWN)

            # Update Admin UIs
            plan = PLANS.get(order_data['plan_key'], {})
            base_caption = (f"✅ **سفارش جدید**\n\n"
                            f"**کد پیگیری:** `{tracking_code}`\n"
                            f"**نام کاربر:** {order_data.get('user_full_name', 'N/A')}\n"
                            f"**ایمیل:** `{order_data.get('user_email', 'N/A')}`\n"
                            f"**پلن:** {generate_plan_label(plan)}\n"
                            f"**روش پرداخت:** {order_data.get('payment_method', 'N/A').capitalize()}")

            admin_message_ids = order_data.get('admin_message_ids', {})
            final_status_text = "✅ تایید شد" if new_status == 'confirmed' else "❌ رد شد"
            final_caption = f"{base_caption}\n\n---\n*{final_status_text} توسط: {admin_name}*"
            for admin_id_str, message_id in admin_message_ids.items():
                try:
                    await context.bot.edit_message_caption(
                        chat_id=int(admin_id_str), message_id=message_id, caption=final_caption,
                        parse_mode=ParseMode.MARKDOWN, reply_markup=None
                    )
                except: pass

    except Exception as e:
        logger.error(f"Error handling admin decision: {e}")
    finally:
        conn.close()

async def logout(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    lang = context.user_data.get('language_code', 'fa')
    context.user_data.clear()
    context.user_data['language_code'] = lang
    await query.message.edit_text(t('logout_success', context))
    return await start(update, context)

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    is_logged_in = context.user_data.get('is_logged_in', False)
    temp_keys = ['selected_plan', 'replying_to_ticket_id', 'broadcast_message', 'new_plan', 'editing_plan', 'payment_method']
    for key in temp_keys: context.user_data.pop(key, None)
    
    message = update.effective_message
    if update.callback_query: message = update.callback_query.message

    await message.reply_text(t('operation_cancelled', context), reply_markup=ReplyKeyboardRemove())
    
    if is_logged_in:
        return await show_main_menu(update, context)
    else:
        context.user_data.clear()
        return await start(update, context)

# ===============================================================
# New Feature: /reqadmin
# ===============================================================
async def request_admin_access(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if is_admin(user.id):
        await update.message.reply_text(t('already_admin', context))
        return

    text_to_admin = (f"**درخواست دسترسی ادمین**\n\n"
                     f"کاربر `{user.full_name}` با شناسه `{user.id}` درخواست دسترسی ادمین دارد.")
    
    keyboard = [[
        InlineKeyboardButton("✅ تایید", callback_data=f"approve_admin:{user.id}:{user.full_name}"),
        InlineKeyboardButton("❌ رد", callback_data=f"deny_admin:{user.id}:{user.full_name}")
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    try:
        await context.bot.send_message(chat_id=ROOT_ADMIN_CHAT_ID, text=text_to_admin, reply_markup=reply_markup, parse_mode=ParseMode.MARKDOWN)
        await update.message.reply_text(t('admin_request_sent', context))
    except Exception as e:
        logger.error(f"Failed to send admin request to root admin: {e}")
        await update.message.reply_text(t('server_error', context))

async def handle_admin_request(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if not is_root_admin(query.from_user.id):
        await query.answer("⛔️ فقط ادمین اصلی می‌تواند این درخواست را مدیریت کند.", show_alert=True)
        return
        
    await query.answer()
    
    match = re.match(r"^(approve_admin|deny_admin):(\d+):(.*)$", query.data)
    if not match: return

    action, user_id_str, user_name = match.groups()
    user_id = int(user_id_str)
    
    original_text = (f"**درخواست دسترسی ادمین**\n\n"
                     f"کاربر `{user_name}` با شناسه `{user_id}` درخواست دسترسی ادمین دارد.")

    conn = get_db_connection()
    user_lang = 'fa'
    if conn:
        with conn.cursor() as cur:
            # Join tables to find lang based on chat_id
            cur.execute("""
                SELECT u.language_code 
                FROM users u 
                JOIN telegram_users t ON u.email = t.email 
                WHERE t.chat_id = %s
            """, (user_id,))
            res = cur.fetchone()
            if res: user_lang = res[0]
        conn.close()

    if action == "approve_admin":
        current_admins = load_admins()
        current_admins.add(user_id)
        save_admins(current_admins)
        
        final_text = original_text + f"\n\n---\n*✅ توسط شما تایید شد.*"
        await context.bot.send_message(chat_id=user_id, text=t_for_user('admin_request_approved', user_lang))
    else:
        final_text = original_text + f"\n\n---\n*❌ توسط شما رد شد.*"
        await context.bot.send_message(chat_id=user_id, text=t_for_user('admin_request_denied', user_lang))

    await query.message.edit_text(final_text, parse_mode=ParseMode.MARKDOWN, reply_markup=None)

def main() -> None:
    # Initialize DB (Create Tables)
    init_db()
    load_translations()
    application = Application.builder().token(BOT_TOKEN).build()

    # --- هندلرهای تیکت (باید اول باشند) ---
    
    # 1. هندلر پاسخ ادمین
    admin_reply_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(reply_to_ticket_start, pattern=r"^reply_ticket:")],
        states={ADMIN_REPLYING: [MessageHandler(filters.TEXT & ~filters.COMMAND, send_reply_to_user)]},
        fallbacks=[CommandHandler("cancel", cancel_admin_reply)],
        conversation_timeout=600,
        per_user=True,
    )
    
    # 2. هندلر پاسخ کاربر (ادامه گفتگو)
    user_reply_conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(continue_ticket_start, pattern=r"^continue_ticket:")],
        states={USER_REPLYING_TO_TICKET: [MessageHandler(filters.TEXT & ~filters.COMMAND, forward_user_reply_to_admins)]},
        fallbacks=[CommandHandler("cancel", cancel)],
        conversation_timeout=600,
        per_user=True,
    )

    # 3. اضافه کردن هندلرهای تیکت به اپلیکیشن (قبل از Main)
    application.add_handler(admin_reply_conv)
    application.add_handler(user_reply_conv)
    
    # 4. هندلرهای مستقل (مثل بستن تیکت یا تایید ادمین) باید قبل از Main باشند
    # تا اگر ادمین در منوی دیگری بود، این دکمه‌ها همچنان کار کنند
    application.add_handler(CommandHandler("reqadmin", request_admin_access))
    application.add_handler(CallbackQueryHandler(handle_admin_request, pattern=r"^(approve_admin|deny_admin):"))
    application.add_handler(CallbackQueryHandler(handle_admin_decision, pattern=r"^(confirm|reject):"))
    application.add_handler(CallbackQueryHandler(close_ticket_admin, pattern=r"^close_ticket:"))

    # --- هندلر اصلی (باید آخر باشد) ---
    main_conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start), CommandHandler("admin", admin_panel_command)],
        states={
            SELECTING_LANGUAGE: [CallbackQueryHandler(set_language, pattern=r"^lang_")],
            GETTING_EMAIL: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_email)],
            GETTING_PHONE: [MessageHandler(filters.CONTACT, get_phone)],
            GETTING_PASSWORD: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, get_password),
                CallbackQueryHandler(forgot_password_start, pattern="^forgot_password_start$")
            ],
            RESET_GET_EMAIL: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, reset_get_email),
                CallbackQueryHandler(reset_get_email, pattern=r"^(confirm_reset_email|change_reset_email)$")
            ],
            RESET_NEW_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, reset_new_password)],
            MAIN_MENU: [
                CallbackQueryHandler(show_payment_methods, pattern="^buy_tokens$"),
                CallbackQueryHandler(check_tokens_callback, pattern="^check_tokens$"),
                CallbackQueryHandler(support_command, pattern="^support$"),
                CallbackQueryHandler(logout, pattern="^logout$"),
                CallbackQueryHandler(admin_panel_command, pattern="^admin_panel_show$"),
                CallbackQueryHandler(close_ticket_user, pattern=r"^user_close_ticket:"),
                CallbackQueryHandler(forgot_password_start, pattern="^change_password_start$")
            ],
            CHOOSING_PAYMENT_METHOD: [
                CallbackQueryHandler(show_plan_menu, pattern=r"^pay_(card|paypal|crypto)$"),
                CallbackQueryHandler(show_main_menu, pattern="^start_menu$"),
            ],
            CHOOSING_PLAN: [
                CallbackQueryHandler(select_plan, pattern=r"^plan_"),
                CallbackQueryHandler(show_payment_methods, pattern="^back_to_payment_methods$"),
            ],
            WAITING_FOR_RECEIPT: [MessageHandler(filters.PHOTO, handle_receipt)],
            GETTING_SUPPORT_MESSAGE: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_support_message)],
            ADMIN_PANEL: [
                CallbackQueryHandler(stats_callback, pattern="^admin_stats$"),
                CallbackQueryHandler(broadcast_start, pattern="^broadcast_start$"),
                CallbackQueryHandler(add_admin_start, pattern="^add_admin_start$"),
                CallbackQueryHandler(remove_admin_start, pattern="^remove_admin_start$"),
                CallbackQueryHandler(list_admins_callback, pattern="^admin_list$"),
                CallbackQueryHandler(manage_plans_menu, pattern="^manage_plans$"),
                CallbackQueryHandler(manage_payment_menu, pattern="^manage_payment$"),
                CallbackQueryHandler(show_main_menu, pattern="^start_menu$"),
                CallbackQueryHandler(admin_panel_command, pattern="^admin_panel_show$")
            ],
            GETTING_ADD_ADMIN_ID: [MessageHandler(filters.TEXT & ~filters.COMMAND, process_add_admin_id)],
            GETTING_REMOVE_ADMIN_ID: [MessageHandler(filters.TEXT & ~filters.COMMAND, process_remove_admin_id)],
            GETTING_BROADCAST_MESSAGE: [MessageHandler(filters.ALL & ~filters.COMMAND, get_broadcast_message)],
            CONFIRM_BROADCAST: [CallbackQueryHandler(confirm_broadcast, pattern=r"^(confirm_broadcast|cancel_broadcast)$")],
            ADMIN_MANAGE_PLANS: [
                CallbackQueryHandler(view_plans_callback, pattern="^view_plans$"),
                CallbackQueryHandler(add_plan_start, pattern="^add_plan_start$"),
                CallbackQueryHandler(edit_plan_start, pattern="^edit_plan_start$"),
                CallbackQueryHandler(remove_plan_start, pattern="^remove_plan_start$"),
                CallbackQueryHandler(admin_panel_command, pattern="^admin_panel_show$"),
                CallbackQueryHandler(confirm_add_plan, pattern="^confirm_add_plan$"),
                CallbackQueryHandler(confirm_plan_edit, pattern="^confirm_edit_plan$"),
                CallbackQueryHandler(manage_plans_menu, pattern="^manage_plans_menu_show$")
            ],
            GETTING_PLAN_TOKENS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_plan_tokens)],
            GETTING_PLAN_PRICE: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_plan_price)],
            GETTING_PLAN_PRICE_USD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_plan_price_usd)],
            REMOVING_PLAN: [CallbackQueryHandler(process_remove_plan, pattern=r"^delete_plan:")],
            EDITING_PLAN_SELECT: [
                CallbackQueryHandler(select_plan_to_edit, pattern=r"^edit_plan:"),
                CallbackQueryHandler(manage_plans_menu, pattern="^manage_plans_menu_show$")
            ],
            GETTING_NEW_PLAN_TOKENS: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_new_plan_tokens)],
            GETTING_NEW_PLAN_PRICE: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_new_plan_price)],
            GETTING_NEW_PLAN_PRICE_USD: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_new_plan_price_usd)],
            ADMIN_MANAGE_PAYMENT: [
                CallbackQueryHandler(edit_card_start, pattern="^edit_card_start$"),
                CallbackQueryHandler(edit_paypal_start, pattern="^edit_paypal_start$"),
                CallbackQueryHandler(edit_crypto_start, pattern="^edit_crypto_start$"),
                CallbackQueryHandler(admin_panel_command, pattern="^admin_panel_show$")
            ],
            GETTING_CARD_NUMBER: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_card_number)],
            GETTING_CARD_OWNER: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_card_owner)],
            GETTING_PAYPAL_EMAIL: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_paypal_email)],
            GETTING_CRYPTO_ADDRESSES: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_crypto_addresses)],
        },
        fallbacks=[CommandHandler("cancel", cancel), CallbackQueryHandler(show_main_menu, pattern="^start_menu$")],
        per_user=True, per_chat=True
    )
    
    application.add_handler(main_conv_handler)
    
    print("Bot is starting to poll...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
