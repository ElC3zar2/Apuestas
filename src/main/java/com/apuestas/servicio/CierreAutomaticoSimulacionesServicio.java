package com.apuestas.servicio;

import com.apuestas.dao.CierreAutomaticoSimulacionesDAO;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.logging.Logger;

/** Un ciclo serial por contexto. SQL decide el vencimiento y la autorizacion. */
public final class CierreAutomaticoSimulacionesServicio implements AutoCloseable {
    private static final Logger LOG=Logger.getLogger(CierreAutomaticoSimulacionesServicio.class.getName());
    private static final int LOTE=20,MAX_FALLOS_RECORDADOS=256;
    private final int actor;
    private final CierreAutomaticoSimulacionesDAO dao;
    private final AtomicBoolean activo=new AtomicBoolean(),revisando=new AtomicBoolean();
    private final Map<Integer,Fallo> fallos=new LinkedHashMap<>();
    private ScheduledThreadPoolExecutor ejecutor;
    private ScheduledFuture<?> tarea;
    private boolean cerrado;
    private int cursor,fallosGlobales;
    private long proximaConsulta;

    public CierreAutomaticoSimulacionesServicio(int actor) {
        if(actor<=0)throw new IllegalArgumentException();
        this.actor=actor;this.dao=new CierreAutomaticoSimulacionesDAO();
    }
    public synchronized void iniciar() {
        if(ejecutor!=null||cerrado)return;
        ejecutor=new ScheduledThreadPoolExecutor(1,trabajo->{
            Thread hilo=new Thread(trabajo,"betzone-autocierre-simulaciones");
            hilo.setDaemon(true);
            hilo.setContextClassLoader(ClassLoader.getPlatformClassLoader());
            return hilo;
        });
        ejecutor.setRemoveOnCancelPolicy(true);
        ejecutor.setContinueExistingPeriodicTasksAfterShutdownPolicy(false);
        ejecutor.setExecuteExistingDelayedTasksAfterShutdownPolicy(false);
        activo.set(true);
        try {tarea=ejecutor.scheduleWithFixedDelay(this::revisar,0,2,TimeUnit.SECONDS);}
        catch(RuntimeException e) {activo.set(false);ejecutor.shutdownNow();throw e;}
        LOG.info("Autocierre programado: revisiones seriales cada 2 segundos; SQL valida actor y vencimiento. No implica disponibilidad de SQL.");
    }
    private void revisar() {
        if(!activo.get()||!revisando.compareAndSet(false,true))return;
        try {
            if(proximaConsulta!=0&&!vencido(proximaConsulta))return;
            List<Integer> candidatos=dao.listarVencidas(actor,cursor,LOTE);
            fallosGlobales=0;proximaConsulta=0;
            if(candidatos.isEmpty()){cursor=0;return;}
            long finCiclo=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
            for(int evento:candidatos) {
                if(!activo.get()||Thread.currentThread().isInterrupted()||vencido(finCiclo))break;
                cursor=evento; // Avanzar tambien ante errores; volver al inicio al agotar la consulta.
                Fallo fallo=fallos.get(evento);
                if(fallo!=null&&!vencido(fallo.reintentar))continue;
                try {
                    CierreAutomaticoSimulacionesDAO.ResultadoCierre r=dao.intentarCerrar(actor,evento);
                    fallos.remove(evento);
                    if(r.realizado)LOG.info("Cierre automatico confirmado: evento="+r.idEvento+"; estado=PENDIENTE_RESULTADO; sin oficializacion ni liquidacion.");
                } catch(SQLException e) {
                    if(!activo.get())break;
                    registrarFallo(evento,e.getErrorCode());
                    if(e.getErrorCode()==59001||e.getErrorCode()==59002||e.getErrorCode()==59003||e.getErrorCode()==59004
                        ||e.getErrorCode()==2812) {aplazarGlobal(e.getErrorCode());break;}
                }
            }
        } catch(SQLException e) {
            if(activo.get())aplazarGlobal(e.getErrorCode());
        } catch(RuntimeException|LinkageError e) {
            if(activo.get()) {
                aplazarGlobal(0);
                LOG.warning("Autocierre no disponible por un fallo interno o de inicializacion. No se registran mensajes del proveedor ni credenciales; requiere revision operativa.");
            }
        } finally {revisando.set(false);}
    }
    private static boolean vencido(long limite) {return System.nanoTime()-limite>=0;}
    private static long espera(int intentos) {return Math.min(300L,30L*(1L<<Math.min(intentos-1,4)));}
    private void registrarFallo(int evento,int codigo) {
        Fallo anterior=fallos.remove(evento);
        int intentos=anterior==null?1:Math.min(anterior.intentos+1,5);
        long segundos=espera(intentos);
        fallos.put(evento,new Fallo(intentos,System.nanoTime()+TimeUnit.SECONDS.toNanos(segundos)));
        if(fallos.size()>MAX_FALLOS_RECORDADOS)fallos.remove(fallos.keySet().iterator().next());
        LOG.warning("Autocierre sin confirmacion: evento="+evento+"; codigo SQL="+codigo+"; espera prevista="+segundos+" segundos en el registro acotado de fallos. Otros eventos continuan.");
    }
    private void aplazarGlobal(int codigo) {
        fallosGlobales=Math.min(fallosGlobales+1,5);
        long segundos=espera(fallosGlobales);
        proximaConsulta=System.nanoTime()+TimeUnit.SECONDS.toNanos(segundos);
        LOG.warning("Revision de autocierre aplazada: codigo SQL="+codigo+"; espera="+segundos+" segundos. Verificar configuracion, identidad tecnica autorizada y procedimientos SQL.");
    }
    @Override public synchronized void close() {
        if(cerrado)return;
        cerrado=true;activo.set(false);
        if(tarea!=null)tarea.cancel(true);
        if(ejecutor==null)return;
        ejecutor.shutdownNow();
        dao.cancelar();
        try {
            if(!ejecutor.awaitTermination(35,TimeUnit.SECONDS))
                LOG.warning("Autocierre aun espera la terminacion JDBC. Verificar cancelacion y timeouts del driver antes de otro redespliegue.");
        } catch(InterruptedException e) {Thread.currentThread().interrupt();}
        // No cerrar ConexionBD: el pool es compartido y tiene otro propietario.
    }
    private static final class Fallo {
        final int intentos;final long reintentar;
        Fallo(int intentos,long reintentar) {this.intentos=intentos;this.reintentar=reintentar;}
    }
}
