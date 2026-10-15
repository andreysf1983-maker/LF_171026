-- ==========================================================================
--   LEGIONFORGE 7.3.5 - учётная запись администратора
--   Файл: sql/47_legionforge_admin.sql
--   Логин (Battle.net): admin@legionforge.ru   Пароль: legionforge
-- ==========================================================================
-- Запросы идемпотентны, повторное применение безопасно.
--
-- Что исправлено относительно первой версии (см. АУДИТ.md):
--   * колонка `mutby` -> `muteby` (в схеме auth она называется muteby);
--   * колонка `SecurityLevel` -> `gmlevel` (так её читает ядро);
--   * создаётся и сама учётная запись Battle.net и связь game <-> battlenet.
--     Раньше вход по e-mail был невозможен: записи в battlenet_accounts не было.
--
-- Формулы хэшей - те же, что в ядре (core/src/server/game/Accounts):
--   game:  SHA1( UPPER(login) : UPPER(пароль) )                               -> HEX
--   bnet:  SHA256( HEX(SHA256(UPPER(email))) : UPPER(пароль) ), байты обратно -> HEX
-- ==========================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

USE `auth`;

SET @lf_user  = 'ADMIN';
SET @lf_email = 'ADMIN@LEGIONFORGE.RU';
SET @lf_pass  = 'LEGIONFORGE';
SET @lf_hash  = UPPER(SHA1(CONCAT(@lf_user, ':', @lf_pass)));
SET @lf_bnet_hash = UPPER(HEX(REVERSE(UNHEX(SHA2(CONCAT(UPPER(SHA2(@lf_email, 256)), ':', @lf_pass), 256)))));

-- --------------------------------------------------------------------------
-- 1. Учётная запись Battle.net (логин в клиенте - e-mail)
-- --------------------------------------------------------------------------

INSERT INTO `battlenet_accounts` (`email`,`sha_pass_hash`)
SELECT @lf_email, @lf_bnet_hash
WHERE NOT EXISTS (SELECT 1 FROM `battlenet_accounts` WHERE `email` = @lf_email);

UPDATE `battlenet_accounts` SET `sha_pass_hash` = @lf_bnet_hash WHERE `email` = @lf_email;

SET @lf_bnet_id = (SELECT `id` FROM `battlenet_accounts` WHERE `email` = @lf_email LIMIT 1);

-- --------------------------------------------------------------------------
-- 2. Игровая учётная запись, привязанная к Battle.net (индекс 1)
-- --------------------------------------------------------------------------

INSERT INTO `account` (`username`,`sha_pass_hash`,`email`,`reg_mail`,`joindate`,`last_ip`,`last_attempt_ip`,`failed_logins`,`locked`,`lock_country`,`online`,`expansion`,`mutetime`,`mutereason`,`muteby`,`locale`,`os`,`recruiter`,`battlenet_account`,`battlenet_index`)
SELECT @lf_user, @lf_hash, @lf_email, @lf_email, NOW(), '127.0.0.1', '127.0.0.1', 0, 0, '00', 0, 6, 0, '', '', 0, 'Win', 0, @lf_bnet_id, 1
WHERE NOT EXISTS (SELECT 1 FROM `account` WHERE `username` = @lf_user);

UPDATE `account`
SET `sha_pass_hash` = @lf_hash, `email` = @lf_email, `reg_mail` = @lf_email, `expansion` = 6,
    `battlenet_account` = @lf_bnet_id, `battlenet_index` = 1
WHERE `username` = @lf_user;

-- --------------------------------------------------------------------------
-- 3. Уровень доступа 3 (администратор) на всех рилмах
-- --------------------------------------------------------------------------

DELETE FROM `account_access` WHERE `id` = (SELECT `id` FROM `account` WHERE `username` = @lf_user);
INSERT INTO `account_access` (`id`,`gmlevel`,`RealmID`)
SELECT `id`, 3, -1 FROM `account` WHERE `username` = @lf_user;

SET FOREIGN_KEY_CHECKS = 1;
