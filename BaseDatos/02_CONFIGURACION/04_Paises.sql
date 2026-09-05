/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/04_Paises.sql

   OBJETIVO:
   Cargar el catálogo base de países.

   IMPORTANTE:
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - Carga códigos ISO2, ISO3, nombre en español y bandera emoji.
   - CodigoTelefonico se deja NULL en esta primera versión porque
     no es obligatorio para la lógica de negocio.
   - No modifica países que ya existan.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.Pais', 'CodigoISO2') IS NULL
    THROW 51001, 'La tabla Pais no contiene la columna CodigoISO2 esperada por 04_Paises.sql.', 1;

IF COL_LENGTH('dbo.Pais', 'CodigoISO3') IS NULL
    THROW 51002, 'La tabla Pais no contiene la columna CodigoISO3 esperada por 04_Paises.sql.', 1;

IF COL_LENGTH('dbo.Pais', 'BanderaEmoji') IS NULL
    THROW 51003, 'La tabla Pais no contiene la columna BanderaEmoji esperada por 04_Paises.sql.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Paises TABLE
    (
        CodigoISO2 CHAR(2) NOT NULL,
        CodigoISO3 CHAR(3) NOT NULL,
        Nombre NVARCHAR(100) NOT NULL,
        CodigoTelefonico VARCHAR(15) NULL,
        BanderaEmoji NVARCHAR(8) NULL,
        Activo BIT NOT NULL
    );

    INSERT INTO @Paises
    (
        CodigoISO2,
        CodigoISO3,
        Nombre,
        CodigoTelefonico,
        BanderaEmoji,
        Activo
    )
        VALUES
        ('AD', 'AND', N'Andorra', '+376', N'🇦🇩', 1),
        ('AE', 'ARE', N'Emiratos Árabes Unidos', '+971', N'🇦🇪', 1),
        ('AF', 'AFG', N'Afganistán', '+93', N'🇦🇫', 1),
        ('AG', 'ATG', N'Antigua y Barbuda', '+1268', N'🇦🇬', 1),
        ('AI', 'AIA', N'Anguila', '+1264', N'🇦🇮', 1),
        ('AL', 'ALB', N'Albania', '+355', N'🇦🇱', 1),
        ('AM', 'ARM', N'Armenia', '+374', N'🇦🇲', 1),
        ('AO', 'AGO', N'Angola', '+244', N'🇦🇴', 1),
        ('AQ', 'ATA', N'Antártida', '+672', N'🇦🇶', 1),
        ('AR', 'ARG', N'Argentina', '+54', N'🇦🇷', 1),
        ('AS', 'ASM', N'Samoa Americana', '+1684', N'🇦🇸', 1),
        ('AT', 'AUT', N'Austria', '+43', N'🇦🇹', 1),
        ('AU', 'AUS', N'Australia', '+61', N'🇦🇺', 1),
        ('AW', 'ABW', N'Aruba', '+297', N'🇦🇼', 1),
        ('AX', 'ALA', N'Islas Aland', '+358', N'🇦🇽', 1),
        ('AZ', 'AZE', N'Azerbaiyán', '+994', N'🇦🇿', 1),
        ('BA', 'BIH', N'Bosnia y Herzegovina', '+387', N'🇧🇦', 1),
        ('BB', 'BRB', N'Barbados', '+1246', N'🇧🇧', 1),
        ('BD', 'BGD', N'Bangladés', '+880', N'🇧🇩', 1),
        ('BE', 'BEL', N'Bélgica', '+32', N'🇧🇪', 1),
        ('BF', 'BFA', N'Burkina Faso', '+226', N'🇧🇫', 1),
        ('BG', 'BGR', N'Bulgaria', '+359', N'🇧🇬', 1),
        ('BH', 'BHR', N'Baréin', '+973', N'🇧🇭', 1),
        ('BI', 'BDI', N'Burundi', '+257', N'🇧🇮', 1),
        ('BJ', 'BEN', N'Benín', '+229', N'🇧🇯', 1),
        ('BL', 'BLM', N'San Bartolomé', '+590', N'🇧🇱', 1),
        ('BM', 'BMU', N'Bermudas', '+1441', N'🇧🇲', 1),
        ('BN', 'BRN', N'Brunéi', '+673', N'🇧🇳', 1),
        ('BO', 'BOL', N'Bolivia', '+591', N'🇧🇴', 1),
        ('BQ', 'BES', N'Caribe neerlandés', '+599', N'🇧🇶', 1),
        ('BR', 'BRA', N'Brasil', '+55', N'🇧🇷', 1),
        ('BS', 'BHS', N'Bahamas', '+1242', N'🇧🇸', 1),
        ('BT', 'BTN', N'Bután', '+975', N'🇧🇹', 1),
        ('BV', 'BVT', N'Isla Bouvet', '+47', N'🇧🇻', 1),
        ('BW', 'BWA', N'Botsuana', '+267', N'🇧🇼', 1),
        ('BY', 'BLR', N'Bielorrusia', '+375', N'🇧🇾', 1),
        ('BZ', 'BLZ', N'Belice', '+501', N'🇧🇿', 1),
        ('CA', 'CAN', N'Canadá', '+1', N'🇨🇦', 1),
        ('CC', 'CCK', N'Islas Cocos', '+61', N'🇨🇨', 1),
        ('CD', 'COD', N'República Democrática del Congo', '+243', N'🇨🇩', 1),
        ('CF', 'CAF', N'República Centroafricana', '+236', N'🇨🇫', 1),
        ('CG', 'COG', N'Congo', '+242', N'🇨🇬', 1),
        ('CH', 'CHE', N'Suiza', '+41', N'🇨🇭', 1),
        ('CI', 'CIV', N'Côte d’Ivoire', '+225', N'🇨🇮', 1),
        ('CK', 'COK', N'Islas Cook', '+682', N'🇨🇰', 1),
        ('CL', 'CHL', N'Chile', '+56', N'🇨🇱', 1),
        ('CM', 'CMR', N'Camerún', '+237', N'🇨🇲', 1),
        ('CN', 'CHN', N'China', '+86', N'🇨🇳', 1),
        ('CO', 'COL', N'Colombia', '+57', N'🇨🇴', 1),
        ('CR', 'CRI', N'Costa Rica', '+506', N'🇨🇷', 1),
        ('CU', 'CUB', N'Cuba', '+53', N'🇨🇺', 1),
        ('CV', 'CPV', N'Cabo Verde', '+238', N'🇨🇻', 1),
        ('CW', 'CUW', N'Curazao', '+599', N'🇨🇼', 1),
        ('CX', 'CXR', N'Isla de Navidad', '+61', N'🇨🇽', 1),
        ('CY', 'CYP', N'Chipre', '+357', N'🇨🇾', 1),
        ('CZ', 'CZE', N'Chequia', '+420', N'🇨🇿', 1),
        ('DE', 'DEU', N'Alemania', '+49', N'🇩🇪', 1),
        ('DJ', 'DJI', N'Yibuti', '+253', N'🇩🇯', 1),
        ('DK', 'DNK', N'Dinamarca', '+45', N'🇩🇰', 1),
        ('DM', 'DMA', N'Dominica', '+1767', N'🇩🇲', 1),
        ('DO', 'DOM', N'República Dominicana', '+1', N'🇩🇴', 1),
        ('DZ', 'DZA', N'Argelia', '+213', N'🇩🇿', 1),
        ('EC', 'ECU', N'Ecuador', '+593', N'🇪🇨', 1),
        ('EE', 'EST', N'Estonia', '+372', N'🇪🇪', 1),
        ('EG', 'EGY', N'Egipto', '+20', N'🇪🇬', 1),
        ('EH', 'ESH', N'Sáhara Occidental', '+212', N'🇪🇭', 1),
        ('ER', 'ERI', N'Eritrea', '+291', N'🇪🇷', 1),
        ('ES', 'ESP', N'España', '+34', N'🇪🇸', 1),
        ('ET', 'ETH', N'Etiopía', '+251', N'🇪🇹', 1),
        ('FI', 'FIN', N'Finlandia', '+358', N'🇫🇮', 1),
        ('FJ', 'FJI', N'Fiyi', '+679', N'🇫🇯', 1),
        ('FK', 'FLK', N'Islas Malvinas', '+500', N'🇫🇰', 1),
        ('FM', 'FSM', N'Micronesia', '+691', N'🇫🇲', 1),
        ('FO', 'FRO', N'Islas Feroe', '+298', N'🇫🇴', 1),
        ('FR', 'FRA', N'Francia', '+33', N'🇫🇷', 1),
        ('GA', 'GAB', N'Gabón', '+241', N'🇬🇦', 1),
        ('GB', 'GBR', N'Reino Unido', '+44', N'🇬🇧', 1),
        ('GD', 'GRD', N'Granada', '+1473', N'🇬🇩', 1),
        ('GE', 'GEO', N'Georgia', '+995', N'🇬🇪', 1),
        ('GF', 'GUF', N'Guayana Francesa', '+594', N'🇬🇫', 1),
        ('GG', 'GGY', N'Guernesey', '+44', N'🇬🇬', 1),
        ('GH', 'GHA', N'Ghana', '+233', N'🇬🇭', 1),
        ('GI', 'GIB', N'Gibraltar', '+350', N'🇬🇮', 1),
        ('GL', 'GRL', N'Groenlandia', '+299', N'🇬🇱', 1),
        ('GM', 'GMB', N'Gambia', '+220', N'🇬🇲', 1),
        ('GN', 'GIN', N'Guinea', '+224', N'🇬🇳', 1),
        ('GP', 'GLP', N'Guadalupe', '+590', N'🇬🇵', 1),
        ('GQ', 'GNQ', N'Guinea Ecuatorial', '+240', N'🇬🇶', 1),
        ('GR', 'GRC', N'Grecia', '+30', N'🇬🇷', 1),
        ('GS', 'SGS', N'Islas Georgia del Sur y Sandwich del Sur', '+500', N'🇬🇸', 1),
        ('GT', 'GTM', N'Guatemala', '+502', N'🇬🇹', 1),
        ('GU', 'GUM', N'Guam', '+1671', N'🇬🇺', 1),
        ('GW', 'GNB', N'Guinea-Bisáu', '+245', N'🇬🇼', 1),
        ('GY', 'GUY', N'Guyana', '+592', N'🇬🇾', 1),
        ('HK', 'HKG', N'RAE de Hong Kong (China)', '+852', N'🇭🇰', 1),
        ('HM', 'HMD', N'Islas Heard y McDonald', '+672', N'🇭🇲', 1),
        ('HN', 'HND', N'Honduras', '+504', N'🇭🇳', 1),
        ('HR', 'HRV', N'Croacia', '+385', N'🇭🇷', 1),
        ('HT', 'HTI', N'Haití', '+509', N'🇭🇹', 1),
        ('HU', 'HUN', N'Hungría', '+36', N'🇭🇺', 1),
        ('ID', 'IDN', N'Indonesia', '+62', N'🇮🇩', 1),
        ('IE', 'IRL', N'Irlanda', '+353', N'🇮🇪', 1),
        ('IL', 'ISR', N'Israel', '+972', N'🇮🇱', 1),
        ('IM', 'IMN', N'Isla de Man', '+44', N'🇮🇲', 1),
        ('IN', 'IND', N'India', '+91', N'🇮🇳', 1),
        ('IO', 'IOT', N'Territorio Británico del Océano Índico', '+246', N'🇮🇴', 1),
        ('IQ', 'IRQ', N'Irak', '+964', N'🇮🇶', 1),
        ('IR', 'IRN', N'Irán', '+98', N'🇮🇷', 1),
        ('IS', 'ISL', N'Islandia', '+354', N'🇮🇸', 1),
        ('IT', 'ITA', N'Italia', '+39', N'🇮🇹', 1),
        ('JE', 'JEY', N'Jersey', '+44', N'🇯🇪', 1),
        ('JM', 'JAM', N'Jamaica', '+1876', N'🇯🇲', 1),
        ('JO', 'JOR', N'Jordania', '+962', N'🇯🇴', 1),
        ('JP', 'JPN', N'Japón', '+81', N'🇯🇵', 1),
        ('KE', 'KEN', N'Kenia', '+254', N'🇰🇪', 1),
        ('KG', 'KGZ', N'Kirguistán', '+996', N'🇰🇬', 1),
        ('KH', 'KHM', N'Camboya', '+855', N'🇰🇭', 1),
        ('KI', 'KIR', N'Kiribati', '+686', N'🇰🇮', 1),
        ('KM', 'COM', N'Comoras', '+269', N'🇰🇲', 1),
        ('KN', 'KNA', N'San Cristóbal y Nieves', '+1869', N'🇰🇳', 1),
        ('KP', 'PRK', N'Corea del Norte', '+850', N'🇰🇵', 1),
        ('KR', 'KOR', N'Corea del Sur', '+82', N'🇰🇷', 1),
        ('KW', 'KWT', N'Kuwait', '+965', N'🇰🇼', 1),
        ('KY', 'CYM', N'Islas Caimán', '+1345', N'🇰🇾', 1),
        ('KZ', 'KAZ', N'Kazajistán', '+7', N'🇰🇿', 1),
        ('LA', 'LAO', N'Laos', '+856', N'🇱🇦', 1),
        ('LB', 'LBN', N'Líbano', '+961', N'🇱🇧', 1),
        ('LC', 'LCA', N'Santa Lucía', '+1758', N'🇱🇨', 1),
        ('LI', 'LIE', N'Liechtenstein', '+423', N'🇱🇮', 1),
        ('LK', 'LKA', N'Sri Lanka', '+94', N'🇱🇰', 1),
        ('LR', 'LBR', N'Liberia', '+231', N'🇱🇷', 1),
        ('LS', 'LSO', N'Lesoto', '+266', N'🇱🇸', 1),
        ('LT', 'LTU', N'Lituania', '+370', N'🇱🇹', 1),
        ('LU', 'LUX', N'Luxemburgo', '+352', N'🇱🇺', 1),
        ('LV', 'LVA', N'Letonia', '+371', N'🇱🇻', 1),
        ('LY', 'LBY', N'Libia', '+218', N'🇱🇾', 1),
        ('MA', 'MAR', N'Marruecos', '+212', N'🇲🇦', 1),
        ('MC', 'MCO', N'Mónaco', '+377', N'🇲🇨', 1),
        ('MD', 'MDA', N'Moldavia', '+373', N'🇲🇩', 1),
        ('ME', 'MNE', N'Montenegro', '+382', N'🇲🇪', 1),
        ('MF', 'MAF', N'San Martín', '+590', N'🇲🇫', 1),
        ('MG', 'MDG', N'Madagascar', '+261', N'🇲🇬', 1),
        ('MH', 'MHL', N'Islas Marshall', '+692', N'🇲🇭', 1),
        ('MK', 'MKD', N'Macedonia del Norte', '+389', N'🇲🇰', 1),
        ('ML', 'MLI', N'Mali', '+223', N'🇲🇱', 1),
        ('MM', 'MMR', N'Myanmar (Birmania)', '+95', N'🇲🇲', 1),
        ('MN', 'MNG', N'Mongolia', '+976', N'🇲🇳', 1),
        ('MO', 'MAC', N'RAE de Macao (China)', '+853', N'🇲🇴', 1),
        ('MP', 'MNP', N'Islas Marianas del Norte', '+1670', N'🇲🇵', 1),
        ('MQ', 'MTQ', N'Martinica', '+596', N'🇲🇶', 1),
        ('MR', 'MRT', N'Mauritania', '+222', N'🇲🇷', 1),
        ('MS', 'MSR', N'Montserrat', '+1664', N'🇲🇸', 1),
        ('MT', 'MLT', N'Malta', '+356', N'🇲🇹', 1),
        ('MU', 'MUS', N'Mauricio', '+230', N'🇲🇺', 1),
        ('MV', 'MDV', N'Maldivas', '+960', N'🇲🇻', 1),
        ('MW', 'MWI', N'Malaui', '+265', N'🇲🇼', 1),
        ('MX', 'MEX', N'México', '+52', N'🇲🇽', 1),
        ('MY', 'MYS', N'Malasia', '+60', N'🇲🇾', 1),
        ('MZ', 'MOZ', N'Mozambique', '+258', N'🇲🇿', 1),
        ('NA', 'NAM', N'Namibia', '+264', N'🇳🇦', 1),
        ('NC', 'NCL', N'Nueva Caledonia', '+687', N'🇳🇨', 1),
        ('NE', 'NER', N'Níger', '+227', N'🇳🇪', 1),
        ('NF', 'NFK', N'Isla Norfolk', '+672', N'🇳🇫', 1),
        ('NG', 'NGA', N'Nigeria', '+234', N'🇳🇬', 1),
        ('NI', 'NIC', N'Nicaragua', '+505', N'🇳🇮', 1),
        ('NL', 'NLD', N'Países Bajos', '+31', N'🇳🇱', 1),
        ('NO', 'NOR', N'Noruega', '+47', N'🇳🇴', 1),
        ('NP', 'NPL', N'Nepal', '+977', N'🇳🇵', 1),
        ('NR', 'NRU', N'Nauru', '+674', N'🇳🇷', 1),
        ('NU', 'NIU', N'Niue', '+683', N'🇳🇺', 1),
        ('NZ', 'NZL', N'Nueva Zelanda', '+64', N'🇳🇿', 1),
        ('OM', 'OMN', N'Omán', '+968', N'🇴🇲', 1),
        ('PA', 'PAN', N'Panamá', '+507', N'🇵🇦', 1),
        ('PE', 'PER', N'Perú', '+51', N'🇵🇪', 1),
        ('PF', 'PYF', N'Polinesia Francesa', '+689', N'🇵🇫', 1),
        ('PG', 'PNG', N'Papúa Nueva Guinea', '+675', N'🇵🇬', 1),
        ('PH', 'PHL', N'Filipinas', '+63', N'🇵🇭', 1),
        ('PK', 'PAK', N'Pakistán', '+92', N'🇵🇰', 1),
        ('PL', 'POL', N'Polonia', '+48', N'🇵🇱', 1),
        ('PM', 'SPM', N'San Pedro y Miquelón', '+508', N'🇵🇲', 1),
        ('PN', 'PCN', N'Islas Pitcairn', '+64', N'🇵🇳', 1),
        ('PR', 'PRI', N'Puerto Rico', '+1', N'🇵🇷', 1),
        ('PS', 'PSE', N'Territorios Palestinos', '+970', N'🇵🇸', 1),
        ('PT', 'PRT', N'Portugal', '+351', N'🇵🇹', 1),
        ('PW', 'PLW', N'Palaos', '+680', N'🇵🇼', 1),
        ('PY', 'PRY', N'Paraguay', '+595', N'🇵🇾', 1),
        ('QA', 'QAT', N'Catar', '+974', N'🇶🇦', 1),
        ('RE', 'REU', N'Reunión', '+262', N'🇷🇪', 1),
        ('RO', 'ROU', N'Rumanía', '+40', N'🇷🇴', 1),
        ('RS', 'SRB', N'Serbia', '+381', N'🇷🇸', 1),
        ('RU', 'RUS', N'Rusia', '+7', N'🇷🇺', 1),
        ('RW', 'RWA', N'Ruanda', '+250', N'🇷🇼', 1),
        ('SA', 'SAU', N'Arabia Saudí', '+966', N'🇸🇦', 1),
        ('SB', 'SLB', N'Islas Salomón', '+677', N'🇸🇧', 1),
        ('SC', 'SYC', N'Seychelles', '+248', N'🇸🇨', 1),
        ('SD', 'SDN', N'Sudán', '+249', N'🇸🇩', 1),
        ('SE', 'SWE', N'Suecia', '+46', N'🇸🇪', 1),
        ('SG', 'SGP', N'Singapur', '+65', N'🇸🇬', 1),
        ('SH', 'SHN', N'Santa Elena', '+290', N'🇸🇭', 1),
        ('SI', 'SVN', N'Eslovenia', '+386', N'🇸🇮', 1),
        ('SJ', 'SJM', N'Svalbard y Jan Mayen', '+47', N'🇸🇯', 1),
        ('SK', 'SVK', N'Eslovaquia', '+421', N'🇸🇰', 1),
        ('SL', 'SLE', N'Sierra Leona', '+232', N'🇸🇱', 1),
        ('SM', 'SMR', N'San Marino', '+378', N'🇸🇲', 1),
        ('SN', 'SEN', N'Senegal', '+221', N'🇸🇳', 1),
        ('SO', 'SOM', N'Somalia', '+252', N'🇸🇴', 1),
        ('SR', 'SUR', N'Surinam', '+597', N'🇸🇷', 1),
        ('SS', 'SSD', N'Sudán del Sur', '+211', N'🇸🇸', 1),
        ('ST', 'STP', N'Santo Tomé y Príncipe', '+239', N'🇸🇹', 1),
        ('SV', 'SLV', N'El Salvador', '+503', N'🇸🇻', 1),
        ('SX', 'SXM', N'Sint Maarten', '+1721', N'🇸🇽', 1),
        ('SY', 'SYR', N'Siria', '+963', N'🇸🇾', 1),
        ('SZ', 'SWZ', N'Esuatini', '+268', N'🇸🇿', 1),
        ('TC', 'TCA', N'Islas Turcas y Caicos', '+1649', N'🇹🇨', 1),
        ('TD', 'TCD', N'Chad', '+235', N'🇹🇩', 1),
        ('TF', 'ATF', N'Territorios Australes Franceses', '+262', N'🇹🇫', 1),
        ('TG', 'TGO', N'Togo', '+228', N'🇹🇬', 1),
        ('TH', 'THA', N'Tailandia', '+66', N'🇹🇭', 1),
        ('TJ', 'TJK', N'Tayikistán', '+992', N'🇹🇯', 1),
        ('TK', 'TKL', N'Tokelau', '+690', N'🇹🇰', 1),
        ('TL', 'TLS', N'Timor-Leste', '+670', N'🇹🇱', 1),
        ('TM', 'TKM', N'Turkmenistán', '+993', N'🇹🇲', 1),
        ('TN', 'TUN', N'Túnez', '+216', N'🇹🇳', 1),
        ('TO', 'TON', N'Tonga', '+676', N'🇹🇴', 1),
        ('TR', 'TUR', N'Turquía', '+90', N'🇹🇷', 1),
        ('TT', 'TTO', N'Trinidad y Tobago', '+1868', N'🇹🇹', 1),
        ('TV', 'TUV', N'Tuvalu', '+688', N'🇹🇻', 1),
        ('TW', 'TWN', N'Taiwán', '+886', N'🇹🇼', 1),
        ('TZ', 'TZA', N'Tanzania', '+255', N'🇹🇿', 1),
        ('UA', 'UKR', N'Ucrania', '+380', N'🇺🇦', 1),
        ('UG', 'UGA', N'Uganda', '+256', N'🇺🇬', 1),
        ('UM', 'UMI', N'Islas menores alejadas de EE. UU.', '+1', N'🇺🇲', 1),
        ('US', 'USA', N'Estados Unidos', '+1', N'🇺🇸', 1),
        ('UY', 'URY', N'Uruguay', '+598', N'🇺🇾', 1),
        ('UZ', 'UZB', N'Uzbekistán', '+998', N'🇺🇿', 1),
        ('VA', 'VAT', N'Ciudad del Vaticano', '+39', N'🇻🇦', 1),
        ('VC', 'VCT', N'San Vicente y las Granadinas', '+1784', N'🇻🇨', 1),
        ('VE', 'VEN', N'Venezuela', '+58', N'🇻🇪', 1),
        ('VG', 'VGB', N'Islas Vírgenes Británicas', '+1284', N'🇻🇬', 1),
        ('VI', 'VIR', N'Islas Vírgenes de EE. UU.', '+1340', N'🇻🇮', 1),
        ('VN', 'VNM', N'Vietnam', '+84', N'🇻🇳', 1),
        ('VU', 'VUT', N'Vanuatu', '+678', N'🇻🇺', 1),
        ('WF', 'WLF', N'Wallis y Futuna', '+681', N'🇼🇫', 1),
        ('WS', 'WSM', N'Samoa', '+685', N'🇼🇸', 1),
        ('YE', 'YEM', N'Yemen', '+967', N'🇾🇪', 1),
        ('YT', 'MYT', N'Mayotte', '+262', N'🇾🇹', 1),
        ('ZA', 'ZAF', N'Sudáfrica', '+27', N'🇿🇦', 1),
        ('ZM', 'ZMB', N'Zambia', '+260', N'🇿🇲', 1),
        ('ZW', 'ZWE', N'Zimbabue', '+263', N'🇿🇼', 1);

        /* ============================================================
       ACTUALIZAR PAISES EXISTENTES
       Corrige nombres, banderas y códigos telefónicos.
       CodigoISO2 se utiliza como identificador estable.
       ============================================================ */

    UPDATE PA
    SET
        PA.CodigoISO3 = P.CodigoISO3,
        PA.Nombre = P.Nombre,
        PA.CodigoTelefonico = P.CodigoTelefonico,
        PA.BanderaEmoji = P.BanderaEmoji,
        PA.Activo = P.Activo
    FROM dbo.Pais AS PA
    INNER JOIN @Paises AS P
        ON P.CodigoISO2 = PA.CodigoISO2;
    INSERT INTO dbo.Pais
    (
        CodigoISO2,
        CodigoISO3,
        Nombre,
        CodigoTelefonico,
        BanderaEmoji,
        Activo
    )
    SELECT
        P.CodigoISO2,
        P.CodigoISO3,
        P.Nombre,
        P.CodigoTelefonico,
        P.BanderaEmoji,
        P.Activo
    FROM @Paises AS P
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Pais AS PA
        WHERE PA.CodigoISO2 = P.CodigoISO2
    );

    COMMIT TRANSACTION;

    PRINT 'Catálogo de países cargado correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO
