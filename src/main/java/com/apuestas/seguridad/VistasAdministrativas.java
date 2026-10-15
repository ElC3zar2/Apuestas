package com.apuestas.seguridad;
import java.util.*;
/** Misma matriz que las operaciones/consultas de cada pantalla. Sin permisos de escritura nuevos. */
public enum VistasAdministrativas {
    INICIO("inicio","AUDITOR"),EVENTOS("eventos","OPERADOR_EVENTOS"),EN_VIVO("en-vivo","OPERADOR_EVENTOS"),
    CATALOGOS("catalogos","OPERADOR_EVENTOS"),MERCADOS("mercados","OPERADOR_EVENTOS"),
    RESULTADOS("resultados","OPERADOR_EVENTOS","AUDITOR"),LIQUIDACIONES("liquidaciones","CAJERO","AUDITOR"),USUARIOS("usuarios","AUDITOR");
    public final String ruta,jsp;private final Set<String> roles;
    VistasAdministrativas(String nombre,String... roles){ruta="/administrador/"+nombre;jsp=ruta+".jsp";this.roles=new HashSet<>(Arrays.asList(roles));}
    public boolean permite(String rol){return "ADMINISTRADOR".equals(rol)||roles.contains(rol);}
    public static VistasAdministrativas deRuta(String ruta){for(VistasAdministrativas v:values())if(v.ruta.equals(ruta))return v;return null;}
    public static VistasAdministrativas deJsp(String ruta){for(VistasAdministrativas v:values())if(v.jsp.equals(ruta))return v;return null;}
    public static String inicio(String rol){return "CAJERO".equals(rol)?LIQUIDACIONES.ruta:"OPERADOR_EVENTOS".equals(rol)?EVENTOS.ruta:INICIO.ruta;}
}
