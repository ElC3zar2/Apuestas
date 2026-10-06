package com.apuestas.servicio;
import com.apuestas.dao.DashboardAdministrativoDAO;
import com.apuestas.modelo.DashboardAdministrativoModelos.*;
import com.apuestas.modelo.OperacionDashboardAdministrativo;
import java.sql.SQLException;
import java.util.*;

public class DashboardAdministrativoServicio {
    private final DashboardAdministrativoDAO dao;
    private static final Set<String> VISTAS=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "TODOS","PROGRAMADOS","PREVIA","EN_PROGRESO","PENDIENTE_RESULTADO","FINALIZADOS","BORRADOR","SUSPENDIDOS","CANCELADOS")));
    public DashboardAdministrativoServicio() { this(new DashboardAdministrativoDAO()); }
    public DashboardAdministrativoServicio(DashboardAdministrativoDAO dao) { this.dao=Objects.requireNonNull(dao); }
    public static void autorizar(int actor,String rol) {
        if(actor<=0||!("ADMINISTRADOR".equals(rol)||"AUDITOR".equals(rol))) throw new SecurityException();
    }
    public Object ejecutar(OperacionDashboardAdministrativo op,int actor,String rol,Map<String,String[]> p) throws SQLException {
        autorizar(actor,rol);
        if(op==null||p==null) throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:p.entrySet())
            if(!op.parametros.contains(e.getKey())||e.getValue()==null||e.getValue().length!=1||e.getValue()[0]==null)
                throw new IllegalArgumentException();
        int horas=numero(p,"horasPrevia",24,Integer.MAX_VALUE);
        if(op==OperacionDashboardAdministrativo.DASHBOARD) {
            int cantidad=numero(p,"cantidadAuditoria",25,100);
            return Objects.requireNonNull(dao.dashboard(actor,new FiltrosDashboard(horas,cantidad)));
        }
        Integer deporte=p.containsKey("idDeporte")?numero(p,"idDeporte",1,Integer.MAX_VALUE):null;
        int cantidad=numero(p,"cantidad",100,500);
        String vista=p.containsKey("vista")?p.get("vista")[0].trim().toUpperCase(Locale.ROOT):"TODOS";
        if(!VISTAS.contains(vista)) throw new IllegalArgumentException();
        return Objects.requireNonNull(dao.eventos(actor,new FiltrosEventos(deporte,vista,horas,cantidad)));
    }
    private static int numero(Map<String,String[]> p,String clave,int defecto,int maximo) {
        if(!p.containsKey(clave)) return defecto;
        String v=p.get(clave)[0].trim();
        if(!v.matches("[0-9]{1,10}")) throw new IllegalArgumentException();
        int n=Integer.parseInt(v);if(n<=0||n>maximo) throw new IllegalArgumentException();return n;
    }
}
