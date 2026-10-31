package com.apuestas.controlador;

import com.apuestas.servicio.CierreAutomaticoSimulacionesServicio;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.logging.Logger;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

/** Unico registro por anotacion; no expone rutas, sesiones ni acciones HTTP. */
@WebListener
public final class InicioCierreAutomaticoSimulacionesListener implements ServletContextListener {
    private static final Logger LOG=Logger.getLogger(InicioCierreAutomaticoSimulacionesListener.class.getName());
    private static final String CLAVE=InicioCierreAutomaticoSimulacionesListener.class.getName()+".servicio";
    @Override public void contextInitialized(ServletContextEvent evento) {
        ServletContext contexto=evento.getServletContext();
        synchronized(contexto) {
            if(contexto.getAttribute(CLAVE)!=null)return;
            contexto.setAttribute(CLAVE,Boolean.FALSE);
            Properties propiedades=new Properties();
            // Mismo recurso classpath usado por ConexionBD; no se escribe configuracion.
            try(InputStream entrada=InicioCierreAutomaticoSimulacionesListener.class.getClassLoader().getResourceAsStream("config.properties")) {
                if(entrada==null) {LOG.warning("Autocierre deshabilitado: falta config.properties en el classpath.");return;}
                propiedades.load(entrada);
            } catch(IOException|RuntimeException e) {
                LOG.warning("Autocierre deshabilitado: no se pudo leer la configuracion del classpath.");return;
            }
            String habilitado=propiedades.getProperty("simulacion.autocierre.habilitado","false").trim();
            if("false".equalsIgnoreCase(habilitado)) {LOG.info("Autocierre deshabilitado por configuracion; se conserva el cierre manual.");return;}
            if(!"true".equalsIgnoreCase(habilitado)) {LOG.warning("Autocierre deshabilitado: simulacion.autocierre.habilitado debe ser true o false.");return;}
            String actorConfigurado=propiedades.getProperty("simulacion.autocierre.actorId","").trim();
            final int actor;
            try {
                if(!actorConfigurado.matches("[1-9][0-9]{0,9}"))throw new IllegalArgumentException();
                actor=Integer.parseInt(actorConfigurado);
            } catch(IllegalArgumentException e) {
                LOG.warning("Autocierre deshabilitado: falta simulacion.autocierre.actorId positivo y expresamente autorizado. No se usa identidad de respaldo.");return;
            }
            CierreAutomaticoSimulacionesServicio servicio=null;
            try {servicio=new CierreAutomaticoSimulacionesServicio(actor);servicio.iniciar();contexto.setAttribute(CLAVE,servicio);}
            catch(RuntimeException|LinkageError e) {
                if(servicio!=null)servicio.close();
                LOG.warning("Autocierre deshabilitado: no se pudo iniciar el ejecutor. Revisar el registro operativo; no se expone la excepcion del proveedor.");
            }
        }
    }
    @Override public void contextDestroyed(ServletContextEvent evento) {
        ServletContext contexto=evento.getServletContext();final Object servicio;
        synchronized(contexto) {servicio=contexto.getAttribute(CLAVE);contexto.removeAttribute(CLAVE);}
        if(servicio instanceof CierreAutomaticoSimulacionesServicio)((CierreAutomaticoSimulacionesServicio)servicio).close();
    }
}
