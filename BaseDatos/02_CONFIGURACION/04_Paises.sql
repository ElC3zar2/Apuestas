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
        ('AD', 'AND', N'Andorra', NULL, N'🇦🇩', 1),
        ('AE', 'ARE', N'Emiratos Árabes Unidos', NULL, N'🇦🇪', 1),
        ('AF', 'AFG', N'Afganistán', NULL, N'🇦🇫', 1),
        ('AG', 'ATG', N'Antigua y Barbuda', NULL, N'🇦🇬', 1),
        ('AI', 'AIA', N'Anguila', NULL, N'🇦🇮', 1),
        ('AL', 'ALB', N'Albania', NULL, N'🇦🇱', 1),
        ('AM', 'ARM', N'Armenia', NULL, N'🇦🇲', 1),
        ('AO', 'AGO', N'Angola', NULL, N'🇦🇴', 1),
        ('AQ', 'ATA', N'Antártida', NULL, N'🇦🇶', 1),
        ('AR', 'ARG', N'Argentina', NULL, N'🇦🇷', 1),
        ('AS', 'ASM', N'Samoa Americana', NULL, N'🇦🇸', 1),
        ('AT', 'AUT', N'Austria', NULL, N'🇦🇹', 1),
        ('AU', 'AUS', N'Australia', NULL, N'🇦🇺', 1),
        ('AW', 'ABW', N'Aruba', NULL, N'🇦🇼', 1),
        ('AX', 'ALA', N'Islas Aland', NULL, N'🇦🇽', 1),
        ('AZ', 'AZE', N'Azerbaiyán', NULL, N'🇦🇿', 1),
        ('BA', 'BIH', N'Bosnia y Herzegovina', NULL, N'🇧🇦', 1),
        ('BB', 'BRB', N'Barbados', NULL, N'🇧🇧', 1),
        ('BD', 'BGD', N'Bangladés', NULL, N'🇧🇩', 1),
        ('BE', 'BEL', N'Bélgica', NULL, N'🇧🇪', 1),
        ('BF', 'BFA', N'Burkina Faso', NULL, N'🇧🇫', 1),
        ('BG', 'BGR', N'Bulgaria', NULL, N'🇧🇬', 1),
        ('BH', 'BHR', N'Baréin', NULL, N'🇧🇭', 1),
        ('BI', 'BDI', N'Burundi', NULL, N'🇧🇮', 1),
        ('BJ', 'BEN', N'Benín', NULL, N'🇧🇯', 1),
        ('BL', 'BLM', N'San Bartolomé', NULL, N'🇧🇱', 1),
        ('BM', 'BMU', N'Bermudas', NULL, N'🇧🇲', 1),
        ('BN', 'BRN', N'Brunéi', NULL, N'🇧🇳', 1),
        ('BO', 'BOL', N'Bolivia', NULL, N'🇧🇴', 1),
        ('BQ', 'BES', N'Caribe neerlandés', NULL, N'🇧🇶', 1),
        ('BR', 'BRA', N'Brasil', NULL, N'🇧🇷', 1),
        ('BS', 'BHS', N'Bahamas', NULL, N'🇧🇸', 1),
        ('BT', 'BTN', N'Bután', NULL, N'🇧🇹', 1),
        ('BV', 'BVT', N'Isla Bouvet', NULL, N'🇧🇻', 1),
        ('BW', 'BWA', N'Botsuana', NULL, N'🇧🇼', 1),
        ('BY', 'BLR', N'Bielorrusia', NULL, N'🇧🇾', 1),
        ('BZ', 'BLZ', N'Belice', NULL, N'🇧🇿', 1),
        ('CA', 'CAN', N'Canadá', NULL, N'🇨🇦', 1),
        ('CC', 'CCK', N'Islas Cocos', NULL, N'🇨🇨', 1),
        ('CD', 'COD', N'República Democrática del Congo', NULL, N'🇨🇩', 1),
        ('CF', 'CAF', N'República Centroafricana', NULL, N'🇨🇫', 1),
        ('CG', 'COG', N'Congo', NULL, N'🇨🇬', 1),
        ('CH', 'CHE', N'Suiza', NULL, N'🇨🇭', 1),
        ('CI', 'CIV', N'Côte d’Ivoire', NULL, N'🇨🇮', 1),
        ('CK', 'COK', N'Islas Cook', NULL, N'🇨🇰', 1),
        ('CL', 'CHL', N'Chile', NULL, N'🇨🇱', 1),
        ('CM', 'CMR', N'Camerún', NULL, N'🇨🇲', 1),
        ('CN', 'CHN', N'China', NULL, N'🇨🇳', 1),
        ('CO', 'COL', N'Colombia', NULL, N'🇨🇴', 1),
        ('CR', 'CRI', N'Costa Rica', NULL, N'🇨🇷', 1),
        ('CU', 'CUB', N'Cuba', NULL, N'🇨🇺', 1),
        ('CV', 'CPV', N'Cabo Verde', NULL, N'🇨🇻', 1),
        ('CW', 'CUW', N'Curazao', NULL, N'🇨🇼', 1),
        ('CX', 'CXR', N'Isla de Navidad', NULL, N'🇨🇽', 1),
        ('CY', 'CYP', N'Chipre', NULL, N'🇨🇾', 1),
        ('CZ', 'CZE', N'Chequia', NULL, N'🇨🇿', 1),
        ('DE', 'DEU', N'Alemania', NULL, N'🇩🇪', 1),
        ('DJ', 'DJI', N'Yibuti', NULL, N'🇩🇯', 1),
        ('DK', 'DNK', N'Dinamarca', NULL, N'🇩🇰', 1),
        ('DM', 'DMA', N'Dominica', NULL, N'🇩🇲', 1),
        ('DO', 'DOM', N'República Dominicana', NULL, N'🇩🇴', 1),
        ('DZ', 'DZA', N'Argelia', NULL, N'🇩🇿', 1),
        ('EC', 'ECU', N'Ecuador', NULL, N'🇪🇨', 1),
        ('EE', 'EST', N'Estonia', NULL, N'🇪🇪', 1),
        ('EG', 'EGY', N'Egipto', NULL, N'🇪🇬', 1),
        ('EH', 'ESH', N'Sáhara Occidental', NULL, N'🇪🇭', 1),
        ('ER', 'ERI', N'Eritrea', NULL, N'🇪🇷', 1),
        ('ES', 'ESP', N'España', NULL, N'🇪🇸', 1),
        ('ET', 'ETH', N'Etiopía', NULL, N'🇪🇹', 1),
        ('FI', 'FIN', N'Finlandia', NULL, N'🇫🇮', 1),
        ('FJ', 'FJI', N'Fiyi', NULL, N'🇫🇯', 1),
        ('FK', 'FLK', N'Islas Malvinas', NULL, N'🇫🇰', 1),
        ('FM', 'FSM', N'Micronesia', NULL, N'🇫🇲', 1),
        ('FO', 'FRO', N'Islas Feroe', NULL, N'🇫🇴', 1),
        ('FR', 'FRA', N'Francia', NULL, N'🇫🇷', 1),
        ('GA', 'GAB', N'Gabón', NULL, N'🇬🇦', 1),
        ('GB', 'GBR', N'Reino Unido', NULL, N'🇬🇧', 1),
        ('GD', 'GRD', N'Granada', NULL, N'🇬🇩', 1),
        ('GE', 'GEO', N'Georgia', NULL, N'🇬🇪', 1),
        ('GF', 'GUF', N'Guayana Francesa', NULL, N'🇬🇫', 1),
        ('GG', 'GGY', N'Guernesey', NULL, N'🇬🇬', 1),
        ('GH', 'GHA', N'Ghana', NULL, N'🇬🇭', 1),
        ('GI', 'GIB', N'Gibraltar', NULL, N'🇬🇮', 1),
        ('GL', 'GRL', N'Groenlandia', NULL, N'🇬🇱', 1),
        ('GM', 'GMB', N'Gambia', NULL, N'🇬🇲', 1),
        ('GN', 'GIN', N'Guinea', NULL, N'🇬🇳', 1),
        ('GP', 'GLP', N'Guadalupe', NULL, N'🇬🇵', 1),
        ('GQ', 'GNQ', N'Guinea Ecuatorial', NULL, N'🇬🇶', 1),
        ('GR', 'GRC', N'Grecia', NULL, N'🇬🇷', 1),
        ('GS', 'SGS', N'Islas Georgia del Sur y Sandwich del Sur', NULL, N'🇬🇸', 1),
        ('GT', 'GTM', N'Guatemala', NULL, N'🇬🇹', 1),
        ('GU', 'GUM', N'Guam', NULL, N'🇬🇺', 1),
        ('GW', 'GNB', N'Guinea-Bisáu', NULL, N'🇬🇼', 1),
        ('GY', 'GUY', N'Guyana', NULL, N'🇬🇾', 1),
        ('HK', 'HKG', N'RAE de Hong Kong (China)', NULL, N'🇭🇰', 1),
        ('HM', 'HMD', N'Islas Heard y McDonald', NULL, N'🇭🇲', 1),
        ('HN', 'HND', N'Honduras', NULL, N'🇭🇳', 1),
        ('HR', 'HRV', N'Croacia', NULL, N'🇭🇷', 1),
        ('HT', 'HTI', N'Haití', NULL, N'🇭🇹', 1),
        ('HU', 'HUN', N'Hungría', NULL, N'🇭🇺', 1),
        ('ID', 'IDN', N'Indonesia', NULL, N'🇮🇩', 1),
        ('IE', 'IRL', N'Irlanda', NULL, N'🇮🇪', 1),
        ('IL', 'ISR', N'Israel', NULL, N'🇮🇱', 1),
        ('IM', 'IMN', N'Isla de Man', NULL, N'🇮🇲', 1),
        ('IN', 'IND', N'India', NULL, N'🇮🇳', 1),
        ('IO', 'IOT', N'Territorio Británico del Océano Índico', NULL, N'🇮🇴', 1),
        ('IQ', 'IRQ', N'Irak', NULL, N'🇮🇶', 1),
        ('IR', 'IRN', N'Irán', NULL, N'🇮🇷', 1),
        ('IS', 'ISL', N'Islandia', NULL, N'🇮🇸', 1),
        ('IT', 'ITA', N'Italia', NULL, N'🇮🇹', 1),
        ('JE', 'JEY', N'Jersey', NULL, N'🇯🇪', 1),
        ('JM', 'JAM', N'Jamaica', NULL, N'🇯🇲', 1),
        ('JO', 'JOR', N'Jordania', NULL, N'🇯🇴', 1),
        ('JP', 'JPN', N'Japón', NULL, N'🇯🇵', 1),
        ('KE', 'KEN', N'Kenia', NULL, N'🇰🇪', 1),
        ('KG', 'KGZ', N'Kirguistán', NULL, N'🇰🇬', 1),
        ('KH', 'KHM', N'Camboya', NULL, N'🇰🇭', 1),
        ('KI', 'KIR', N'Kiribati', NULL, N'🇰🇮', 1),
        ('KM', 'COM', N'Comoras', NULL, N'🇰🇲', 1),
        ('KN', 'KNA', N'San Cristóbal y Nieves', NULL, N'🇰🇳', 1),
        ('KP', 'PRK', N'Corea del Norte', NULL, N'🇰🇵', 1),
        ('KR', 'KOR', N'Corea del Sur', NULL, N'🇰🇷', 1),
        ('KW', 'KWT', N'Kuwait', NULL, N'🇰🇼', 1),
        ('KY', 'CYM', N'Islas Caimán', NULL, N'🇰🇾', 1),
        ('KZ', 'KAZ', N'Kazajistán', NULL, N'🇰🇿', 1),
        ('LA', 'LAO', N'Laos', NULL, N'🇱🇦', 1),
        ('LB', 'LBN', N'Líbano', NULL, N'🇱🇧', 1),
        ('LC', 'LCA', N'Santa Lucía', NULL, N'🇱🇨', 1),
        ('LI', 'LIE', N'Liechtenstein', NULL, N'🇱🇮', 1),
        ('LK', 'LKA', N'Sri Lanka', NULL, N'🇱🇰', 1),
        ('LR', 'LBR', N'Liberia', NULL, N'🇱🇷', 1),
        ('LS', 'LSO', N'Lesoto', NULL, N'🇱🇸', 1),
        ('LT', 'LTU', N'Lituania', NULL, N'🇱🇹', 1),
        ('LU', 'LUX', N'Luxemburgo', NULL, N'🇱🇺', 1),
        ('LV', 'LVA', N'Letonia', NULL, N'🇱🇻', 1),
        ('LY', 'LBY', N'Libia', NULL, N'🇱🇾', 1),
        ('MA', 'MAR', N'Marruecos', NULL, N'🇲🇦', 1),
        ('MC', 'MCO', N'Mónaco', NULL, N'🇲🇨', 1),
        ('MD', 'MDA', N'Moldavia', NULL, N'🇲🇩', 1),
        ('ME', 'MNE', N'Montenegro', NULL, N'🇲🇪', 1),
        ('MF', 'MAF', N'San Martín', NULL, N'🇲🇫', 1),
        ('MG', 'MDG', N'Madagascar', NULL, N'🇲🇬', 1),
        ('MH', 'MHL', N'Islas Marshall', NULL, N'🇲🇭', 1),
        ('MK', 'MKD', N'Macedonia del Norte', NULL, N'🇲🇰', 1),
        ('ML', 'MLI', N'Mali', NULL, N'🇲🇱', 1),
        ('MM', 'MMR', N'Myanmar (Birmania)', NULL, N'🇲🇲', 1),
        ('MN', 'MNG', N'Mongolia', NULL, N'🇲🇳', 1),
        ('MO', 'MAC', N'RAE de Macao (China)', NULL, N'🇲🇴', 1),
        ('MP', 'MNP', N'Islas Marianas del Norte', NULL, N'🇲🇵', 1),
        ('MQ', 'MTQ', N'Martinica', NULL, N'🇲🇶', 1),
        ('MR', 'MRT', N'Mauritania', NULL, N'🇲🇷', 1),
        ('MS', 'MSR', N'Montserrat', NULL, N'🇲🇸', 1),
        ('MT', 'MLT', N'Malta', NULL, N'🇲🇹', 1),
        ('MU', 'MUS', N'Mauricio', NULL, N'🇲🇺', 1),
        ('MV', 'MDV', N'Maldivas', NULL, N'🇲🇻', 1),
        ('MW', 'MWI', N'Malaui', NULL, N'🇲🇼', 1),
        ('MX', 'MEX', N'México', NULL, N'🇲🇽', 1),
        ('MY', 'MYS', N'Malasia', NULL, N'🇲🇾', 1),
        ('MZ', 'MOZ', N'Mozambique', NULL, N'🇲🇿', 1),
        ('NA', 'NAM', N'Namibia', NULL, N'🇳🇦', 1),
        ('NC', 'NCL', N'Nueva Caledonia', NULL, N'🇳🇨', 1),
        ('NE', 'NER', N'Níger', NULL, N'🇳🇪', 1),
        ('NF', 'NFK', N'Isla Norfolk', NULL, N'🇳🇫', 1),
        ('NG', 'NGA', N'Nigeria', NULL, N'🇳🇬', 1),
        ('NI', 'NIC', N'Nicaragua', NULL, N'🇳🇮', 1),
        ('NL', 'NLD', N'Países Bajos', NULL, N'🇳🇱', 1),
        ('NO', 'NOR', N'Noruega', NULL, N'🇳🇴', 1),
        ('NP', 'NPL', N'Nepal', NULL, N'🇳🇵', 1),
        ('NR', 'NRU', N'Nauru', NULL, N'🇳🇷', 1),
        ('NU', 'NIU', N'Niue', NULL, N'🇳🇺', 1),
        ('NZ', 'NZL', N'Nueva Zelanda', NULL, N'🇳🇿', 1),
        ('OM', 'OMN', N'Omán', NULL, N'🇴🇲', 1),
        ('PA', 'PAN', N'Panamá', NULL, N'🇵🇦', 1),
        ('PE', 'PER', N'Perú', NULL, N'🇵🇪', 1),
        ('PF', 'PYF', N'Polinesia Francesa', NULL, N'🇵🇫', 1),
        ('PG', 'PNG', N'Papúa Nueva Guinea', NULL, N'🇵🇬', 1),
        ('PH', 'PHL', N'Filipinas', NULL, N'🇵🇭', 1),
        ('PK', 'PAK', N'Pakistán', NULL, N'🇵🇰', 1),
        ('PL', 'POL', N'Polonia', NULL, N'🇵🇱', 1),
        ('PM', 'SPM', N'San Pedro y Miquelón', NULL, N'🇵🇲', 1),
        ('PN', 'PCN', N'Islas Pitcairn', NULL, N'🇵🇳', 1),
        ('PR', 'PRI', N'Puerto Rico', NULL, N'🇵🇷', 1),
        ('PS', 'PSE', N'Territorios Palestinos', NULL, N'🇵🇸', 1),
        ('PT', 'PRT', N'Portugal', NULL, N'🇵🇹', 1),
        ('PW', 'PLW', N'Palaos', NULL, N'🇵🇼', 1),
        ('PY', 'PRY', N'Paraguay', NULL, N'🇵🇾', 1),
        ('QA', 'QAT', N'Catar', NULL, N'🇶🇦', 1),
        ('RE', 'REU', N'Reunión', NULL, N'🇷🇪', 1),
        ('RO', 'ROU', N'Rumanía', NULL, N'🇷🇴', 1),
        ('RS', 'SRB', N'Serbia', NULL, N'🇷🇸', 1),
        ('RU', 'RUS', N'Rusia', NULL, N'🇷🇺', 1),
        ('RW', 'RWA', N'Ruanda', NULL, N'🇷🇼', 1),
        ('SA', 'SAU', N'Arabia Saudí', NULL, N'🇸🇦', 1),
        ('SB', 'SLB', N'Islas Salomón', NULL, N'🇸🇧', 1),
        ('SC', 'SYC', N'Seychelles', NULL, N'🇸🇨', 1),
        ('SD', 'SDN', N'Sudán', NULL, N'🇸🇩', 1),
        ('SE', 'SWE', N'Suecia', NULL, N'🇸🇪', 1),
        ('SG', 'SGP', N'Singapur', NULL, N'🇸🇬', 1),
        ('SH', 'SHN', N'Santa Elena', NULL, N'🇸🇭', 1),
        ('SI', 'SVN', N'Eslovenia', NULL, N'🇸🇮', 1),
        ('SJ', 'SJM', N'Svalbard y Jan Mayen', NULL, N'🇸🇯', 1),
        ('SK', 'SVK', N'Eslovaquia', NULL, N'🇸🇰', 1),
        ('SL', 'SLE', N'Sierra Leona', NULL, N'🇸🇱', 1),
        ('SM', 'SMR', N'San Marino', NULL, N'🇸🇲', 1),
        ('SN', 'SEN', N'Senegal', NULL, N'🇸🇳', 1),
        ('SO', 'SOM', N'Somalia', NULL, N'🇸🇴', 1),
        ('SR', 'SUR', N'Surinam', NULL, N'🇸🇷', 1),
        ('SS', 'SSD', N'Sudán del Sur', NULL, N'🇸🇸', 1),
        ('ST', 'STP', N'Santo Tomé y Príncipe', NULL, N'🇸🇹', 1),
        ('SV', 'SLV', N'El Salvador', NULL, N'🇸🇻', 1),
        ('SX', 'SXM', N'Sint Maarten', NULL, N'🇸🇽', 1),
        ('SY', 'SYR', N'Siria', NULL, N'🇸🇾', 1),
        ('SZ', 'SWZ', N'Esuatini', NULL, N'🇸🇿', 1),
        ('TC', 'TCA', N'Islas Turcas y Caicos', NULL, N'🇹🇨', 1),
        ('TD', 'TCD', N'Chad', NULL, N'🇹🇩', 1),
        ('TF', 'ATF', N'Territorios Australes Franceses', NULL, N'🇹🇫', 1),
        ('TG', 'TGO', N'Togo', NULL, N'🇹🇬', 1),
        ('TH', 'THA', N'Tailandia', NULL, N'🇹🇭', 1),
        ('TJ', 'TJK', N'Tayikistán', NULL, N'🇹🇯', 1),
        ('TK', 'TKL', N'Tokelau', NULL, N'🇹🇰', 1),
        ('TL', 'TLS', N'Timor-Leste', NULL, N'🇹🇱', 1),
        ('TM', 'TKM', N'Turkmenistán', NULL, N'🇹🇲', 1),
        ('TN', 'TUN', N'Túnez', NULL, N'🇹🇳', 1),
        ('TO', 'TON', N'Tonga', NULL, N'🇹🇴', 1),
        ('TR', 'TUR', N'Turquía', NULL, N'🇹🇷', 1),
        ('TT', 'TTO', N'Trinidad y Tobago', NULL, N'🇹🇹', 1),
        ('TV', 'TUV', N'Tuvalu', NULL, N'🇹🇻', 1),
        ('TW', 'TWN', N'Taiwán', NULL, N'🇹🇼', 1),
        ('TZ', 'TZA', N'Tanzania', NULL, N'🇹🇿', 1),
        ('UA', 'UKR', N'Ucrania', NULL, N'🇺🇦', 1),
        ('UG', 'UGA', N'Uganda', NULL, N'🇺🇬', 1),
        ('UM', 'UMI', N'Islas menores alejadas de EE. UU.', NULL, N'🇺🇲', 1),
        ('US', 'USA', N'Estados Unidos', NULL, N'🇺🇸', 1),
        ('UY', 'URY', N'Uruguay', NULL, N'🇺🇾', 1),
        ('UZ', 'UZB', N'Uzbekistán', NULL, N'🇺🇿', 1),
        ('VA', 'VAT', N'Ciudad del Vaticano', NULL, N'🇻🇦', 1),
        ('VC', 'VCT', N'San Vicente y las Granadinas', NULL, N'🇻🇨', 1),
        ('VE', 'VEN', N'Venezuela', NULL, N'🇻🇪', 1),
        ('VG', 'VGB', N'Islas Vírgenes Británicas', NULL, N'🇻🇬', 1),
        ('VI', 'VIR', N'Islas Vírgenes de EE. UU.', NULL, N'🇻🇮', 1),
        ('VN', 'VNM', N'Vietnam', NULL, N'🇻🇳', 1),
        ('VU', 'VUT', N'Vanuatu', NULL, N'🇻🇺', 1),
        ('WF', 'WLF', N'Wallis y Futuna', NULL, N'🇼🇫', 1),
        ('WS', 'WSM', N'Samoa', NULL, N'🇼🇸', 1),
        ('YE', 'YEM', N'Yemen', NULL, N'🇾🇪', 1),
        ('YT', 'MYT', N'Mayotte', NULL, N'🇾🇹', 1),
        ('ZA', 'ZAF', N'Sudáfrica', NULL, N'🇿🇦', 1),
        ('ZM', 'ZMB', N'Zambia', NULL, N'🇿🇲', 1),
        ('ZW', 'ZWE', N'Zimbabue', NULL, N'🇿🇼', 1);

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
