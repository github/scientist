¡Científico!
Una biblioteca Ruby para refactorizar cuidadosamente las rutas críticas. Estado de construcción Estado de cobertura

¿Cómo hago ciencia?
Supongamos que está cambiando la forma en que maneja los permisos en una aplicación web grande. Las pruebas pueden ayudar a guiar su refactorización, pero realmente desea comparar los comportamientos actuales y refactorizados bajo carga.

requiere  "científico"

clase  MyWidget 
  def  permite? ( usuario ) 
    experimento  =  Científico :: Predeterminado . nuevo  experimento de "permisos de widget" 
    . use { modelo . check_user? ( usuario ) . ¿válido? } # experimento a la antigua . prueba con { usuario . ¿pueden? ( : leer , modelo ) } # nueva forma    
         

    Experimentar . ejecutar 
  fin 
fin
Envuelva un usebloque alrededor del comportamiento original del código y envuelva tryel nuevo comportamiento. experiment.runsiempre devolverá lo que devuelva el usebloque, pero hace un montón de cosas detrás de escena:

Decide si ejecutar o no el trybloque,
Aleatoriza el orden en el que se ejecutan los bloques usey try,
Mide la duración de todos los comportamientos en segundos,
Compara el resultado de trycon el resultado de use,
Trague y registre las excepciones planteadas en el trybloque al anular raised, y
Publica toda esta información.
El usebloque se llama control . El trybloque se llama candidato .

Crear un experimento es complicado, pero cuando incluye el Scientistmódulo, el scienceasistente creará una instancia de un experimento y lo llamará run:

requiere  "científico"

clase  MyWidget 
  incluye  Científico

  def  permite? ( usuario ) 
    ciencia  "permisos de widget"  hacer | experimento |
      Experimentar . use  {  modelo . check_user ( usuario ) . ¿válido?  }  # 
      experimento a la antigua . prueba con  {  usuario . ¿pueden? ( : lectura ,  modelo )  }  # new way 
    end  # devuelve el valor de control 
  end 
end
Si no declara ningún trybloque, no se invoca ninguna de las máquinas del científico y siempre se devuelve el valor de control.

Hacer que la ciencia sea útil
Los ejemplos anteriores se ejecutarán, pero en realidad no están haciendo nada. Los trybloques aún no se ejecutan y no se publica ninguno de los resultados. Reemplace la implementación del experimento predeterminada para controlar la ejecución y los informes:

requiere  "científico / experimento"

clase  MyExperiment 
  incluye  Científico :: Experimento

  attr_accessor  : nombre

  def  initialize ( name ) 
    @name  =  name 
  end

  def enabled?
    # see "Ramping up experiments" below
    true
  end

  def raised(operation, error)
    # see "In a Scientist callback" below
    p "Operation '#{operation}' failed with error '#{error.inspect}'"
    super # will re-raise
  end

  def publish(result)
    # see "Publishing results" below
    p result
  end
end
Now calls to the science helper will load instances of MyExperiment.

Controlling comparison
El científico compara los valores de control y candidatos utilizando ==. Para anular este comportamiento, utilice comparepara definir cómo comparar los valores observados en su lugar:

clase  MyWidget 
  incluye  Científico

  def  usuarios 
    ciencia  "usuarios"  hacen | e |
      e . use  {  Usuario . all  }          # devuelve instancias de usuario 
      e . intente  {  UserService . list  }  # devuelve UserService :: instancias de usuario

      e . comparar  hacer | control ,  candidato |
        control . map ( & : login ) == candidato . map ( & : login ) 
      end 
    end 
  end 
end
Agregar contexto
Los resultados no son muy útiles sin alguna forma de identificarlos. Utilice el contextmétodo para agregar o recuperar el contexto de un experimento:

ciencia  "permisos de widget"  hacen | e |
  e . contexto  : usuario  =>  usuario

  e . use  {  modelo . check_user ( usuario ) . ¿válido?  } 
  e . prueba con  {  usuario . ¿pueden? ( : leer ,  modelo )  } 
fin
contexttoma un hash de datos adicionales con clave de símbolo. Los datos están disponibles a Experiment#publishtravés del contextmétodo. Si usa mucho el scienceayudante en una clase, puede proporcionar un contexto predeterminado:

clase  MyWidget 
  incluye  Científico

  def  permite? ( usuario ) 
    ciencia  "permisos de widget"  hacer | e |
      e . contexto  : usuario  =>  usuario

      e . use  {  modelo . check_user ( usuario ) . ¿válido?  } 
      e . prueba con  {  usuario . ¿pueden? ( : leer ,  modelo )  } 
    end 
  end

  def  destruir 
    ciencia  "widget-destrucción"  hacer | e |
      e . usar  {  old_scary_destroy  } 
      e . prueba  {  new_safe_destroy  } 
    end 
  end

  def  default_scientist_context 
    {  : widget  =>  self  } 
  end 
end
Los experimentos widget-permissionsy widget-destructiontendrán una :widgetclave en sus contextos.

Configuración costosa
Si un experimento requiere una configuración costosa que solo debería ocurrir cuando el experimento se va a ejecutar, defínalo con el before_runmétodo:

# Code under test modifies this in-place. We want to copy it for the
# candidate code, but only when needed:
value_for_original_code = big_object
value_for_new_code      = nil

science "expensive-but-worthwhile" do |e|
  e.before_run do
    value_for_new_code = big_object.deep_copy
  end
  e.use { original_code(value_for_original_code) }
  e.try { new_code(value_for_new_code) }
end
Keeping it clean
Sometimes you don't want to store the full value for later analysis. For example, an experiment may return User instances, but when researching a mismatch, all you care about is the logins. You can define how to clean these values in an experiment:

class MyWidget
  include Scientist

  def users
    science "users" do |e|
      e.use { User.all }
      e.try { UserService.list }

      e.clean do |value|
        value.map(&:login).sort
      end
    end
  end
end
And this cleaned value is available in observations in the final published result:

class MyExperiment
  include Scientist::Experiment

  # ...

  def publish(result)
    result.control.value         # [<User alice>, <User bob>, <User carol>]
    result.control.cleaned_value # ["alice", "bob", "carol"]
  end
end
Note that the #clean method will discard the previous cleaner block if you call it again. If for some reason you need to access the currently configured cleaner block, Scientist::Experiment#cleaner will return the block without further ado. (This probably won't come up in normal usage, but comes in handy if you're writing, say, a custom experiment runner that provides default cleaners.)

Ignoring mismatches
During the early stages of an experiment, it's possible that some of your code will always generate a mismatch for reasons you know and understand but haven't yet fixed. Instead of these known cases always showing up as mismatches in your metrics or analysis, you can tell an experiment whether or not to ignore a mismatch using the ignore method. You may include more than one block if needed:

def admin?(user)
  science "widget-permissions" do |e|
    e.use { model.check_user(user).admin? }
    e.try { user.can?(:admin, model) }

    e.ignore { user.staff? } # user is staff, always an admin in the new system
    e.ignore do |control, candidate|
      # new system doesn't handle unconfirmed users yet:
      control && !candidate && !user.confirmed_email?
    end
  end
end
The ignore blocks are only called if the values don't match. If one observation raises an exception and the other doesn't, it's always considered a mismatch. If both observations raise different exceptions, that is also considered a mismatch.

Habilitar / deshabilitar experimentos
A veces no desea que se ejecute un experimento. Digamos, deshabilitar una nueva ruta de código para cualquier persona que no sea personal. Puede deshabilitar un experimento estableciendo un run_ifbloqueo. Si esto regresa false, el experimento simplemente devolverá el valor de control. De lo contrario, difiere del enabled?método configurado del experimento .

class  DashboardController 
  incluye  Scientist

  def  dashboard_items 
    ciencia  "elementos de panel"  hacer | e |
      # ejecutar este experimento únicamente para miembros del personal 
      e . run_if  {  current_user . ¿personal?  } 
      # ... 
  end 
end
Incrementando los experimentos
Como científico, usted sabe que siempre es importante poder apagar su experimento, no sea que se vuelva loco y resulte en aldeanos con horquillas en la puerta de su casa. Para controlar si un experimento está habilitado o no, debe incluir el enabled?método en su Scientist::Experimentimplementación.

clase  MyExperiment 
  incluye  Científico :: Experimento

  attr_accessor  : nombre ,  : percent_enabled

  def  initialize ( nombre ) 
    @name  =  nombre 
    @percent_enabled  =  100 
  end

  def  habilitado? 
    percent_enabled > 0 && rand ( 100 ) < percent_enabled 
  end

  # ...

fin
Este código se invocará para cada método con un experimento cada vez, así que tenga en cuenta su rendimiento. Por ejemplo, puede almacenar un experimento en la base de datos pero envolverlo en varios niveles de almacenamiento en caché, como Memcache o subprocesos locales por solicitud.

Publicar resultados
¿De qué sirve la ciencia si no puedes publicar tus resultados?

Debe implementar el publish(result)método y puede publicar datos como desee. Por ejemplo, los datos de tiempo se pueden enviar al grafito y los desajustes se pueden colocar en una colección limitada en redis para depurarlos más tarde.

El publishmétodo recibe una Scientist::Resultinstancia con sus Scientist::Observations asociados :

clase  MyExperiment 
  incluye  Científico :: Experimento

  # ...

  def  publicar ( resultado )

    # Almacene el tiempo para el valor de control, 
    $ statsd . cronometraje  "ciencia. # { nombre } .control" ,  resultado . control . duración 
    # para el candidato (solo el primero, consulte "Rompiendo las reglas" a continuación, 
    $ statsd . timing  "ciencia. # { nombre } .candidate" ,  resultado . candidatos . primero . duración

    # y cuenta para coincidencia / ignorar / discrepancia: 
    si  resulta . emparejado? 
      $ statsd . incremento  "ciencia. # { nombre } .matched" 
    resultado elsif  . ignorado? 
      $ statsd . incrementar "ciencia. # { nombre } .ignorado" else 
      $ statsd . increment "science. # { name } .mismatched" # Finalmente, almacene los desajustes en redis para que puedan ser recuperados y examinados # más adelante, para depuración e investigación. store_mismatch_data ( 
     
      
      
      resultado ) 
    fin 
  fin

  def  store_mismatch_data ( resultado ) 
    de carga útil  =  { 
      : Nombre             =>  nombre , 
      : contexto          =>  contexto , 
      : Control          =>  observation_payload ( resultado . de control ) , 
      : candidato        =>  observation_payload ( resultado . candidatos . primeros ) , 
      : execution_order  =>  resultado . observaciones . mapa ( & : nombre ) 
    }

    key  =  "ciencia. # { nombre } .mismatch" 
    $ redis . lpush  key ,  payload 
    $ redis . ltrim  key ,  0 ,  1000 
  end

  def  observación_payload ( observación ) 
    if  observación . ¿elevado? 
      { 
        : excepción  =>  observación . excepción . clase , 
        : Mensaje    =>  observación . excepción . mensaje , 
        : backtrace  =>  observación . excepción . backtrace 
      } 
    else 
      { 
        # ver "Manteniéndolo limpio" arriba 
        : valor  =>  observación . clean_value 
      } 
    end 
  end 
end
Pruebas
Al ejecutar su conjunto de pruebas, es útil saber que los resultados experimentales siempre coinciden. Para ayudar con las pruebas, Scientist define un raise_on_mismatchesatributo de clase cuando se incluye Scientist::Experiment. ¡Solo haga esto en su suite de prueba!

Para plantear los desajustes:

class  MyExperiment 
  incluye  Scientist :: Experiment 
  # ... Implementación 
final

MyExperiment . raise_on_mismatches  =  verdadero
El científico planteará una Scientist::Experiment::MismatchErrorexcepción si alguna observación no coincide.

Errores de discrepancia personalizados
Para indicar al científico que genere un error personalizado en lugar del predeterminado Scientist::Experiment::MismatchError:

class  CustomMismatchError < Scientist :: Experiment :: MismatchError 
  def  to_s 
    message  =  "¡Hubo una falta de coincidencia! Aquí está la diferencia:"

    diffs  =  resultado . candidatos . mapa  hacer | candidato |
      Dif . nuevo ( resultado . control ,  candidato ) 
    final . unirse ( " \ n " )

    " # { mensaje } \ n # { diffs } " 
  end 
end
ciencia  "permisos de widget"  hacen | e |
  e . use  {  Informe . encontrar ( id )  } 
  e . pruebe  {  ReportService . nuevo . buscar ( id )  }

  e . raise_with  CustomMismatchError 
end
Esto permite el procesamiento previo de mensajes de excepción de error de discrepancia.

Manejo de errores
En código candidato
El científico rescata y rastrea todas las excepciones planteadas en un bloque tryo use, incluidas algunas en las que el rescate puede causar un comportamiento inesperado (como SystemExito ScriptError). Para rescatar un conjunto de excepciones más restrictivo, modifique la RESCUESlista:

# por defecto es [Excepción] 
Científico :: Observación :: RESCATE . reemplazar  [ StandardError ]
En una devolución de llamada de un científico
Si se genera una excepción dentro de cualquiera de los ayudantes internos de Scientist, como publish, compareo clean, el raisedmétodo se llama con el nombre del símbolo de la operación interna que falló y la excepción que se generó. El comportamiento predeterminado de Scientist::Defaultes simplemente volver a generar la excepción. Dado que esto detiene el experimento por completo, a menudo es una mejor idea manejar este error y continuar para que el experimento en su conjunto no se cancele por completo:

clase  MyExperiment 
  incluye  Científico :: Experimento

  # ...

  def  elevado ( operación ,  error ) 
    InternalErrorTracker . ¡pista!  "falla científica en # { nombre } : # { operación } " ,  error 
  end 
end
Las operaciones que pueden manejarse aquí son:

:clean- se genera una excepción en un cleanbloque
:compare- se genera una excepción en un comparebloque
:enabled- se genera una excepción en el enabled?método
:ignore- se genera una excepción en un ignorebloque
:publish- se genera una excepción en el publishmétodo
:run_if- se genera una excepción en un run_ifbloque
Diseñando un experimento
Porque enabled?y run_ifdeterminar cuándo se presenta un candidato, es imposible garantizar que se ejecutará siempre. Por esta razón, Scientist solo es seguro para empaquetar métodos que no cambian los datos.

Al utilizar Scientist, nos ha resultado más útil modificar los sistemas nuevos y existentes simultáneamente en cualquier lugar donde se produzcan escrituras y verificar los resultados en el tiempo de lectura con science. raise_on_mismatchestambién ha sido útil para garantizar que se escribieron los datos correctos durante las pruebas, y revisar las discrepancias publicadas nos ha ayudado a encontrar cualquier situación que pasamos por alto con nuestros datos de producción en tiempo de ejecución. Al escribir y leer en dos sistemas, también es útil escribir algunos scripts de reconciliación de datos para verificar y limpiar los datos de producción junto con cualquier experimento en ejecución.

Tasas de ruido y error
Tenga en cuenta que los bloques Científico tryy usese ejecutan secuencialmente en orden aleatorio. Como tal, cualquier dato del que dependa su código puede cambiar antes de que se invoque el segundo bloque, lo que podría generar una falta de coincidencia entre los valores de retorno del candidato y del control. Para calibrar sus expectativas con respecto a los falsos negativos que surgen de condiciones sistémicas externas a los cambios propuestos, considere comenzar con un experimento en el que los bloques tryy useinvoquen el método de control. Luego proceda con la presentación de un candidato.

Terminando un experimento
A medida que su comportamiento candidato converja en los controles, comenzará a pensar en eliminar un experimento y utilizar el nuevo comportamiento.

Si hay bloques ignorados, se garantiza que el comportamiento del candidato será diferente. Si esto es inaceptable, deberá eliminar los bloques de ignorar y resolver cualquier desajuste continuo en el comportamiento hasta que las observaciones coincidan perfectamente en todo momento.
Al eliminar un experimento de comportamiento de lectura, es una buena idea mantener en su lugar cualquier duplicación del lado de escritura entre un sistema nuevo y antiguo hasta mucho después de que el nuevo comportamiento haya estado en producción, en caso de que necesite revertir.
Rompiendo las reglas
A veces, los científicos solo tienen que hacer cosas raras. Entendemos.

Ignorando los resultados por completo
La ciencia es útil incluso cuando lo único que te importa son los datos de tiempo o incluso si estalló o no una nueva ruta de código. Si tiene la capacidad de controlar de forma incremental la frecuencia con la que se ejecuta un experimento a través de su enabled?método, puede usarlo para probar silenciosamente y con cuidado nuevas rutas de código e ignorar los resultados por completo. Usted puede hacer esto mediante el establecimiento ignore { true }, o para una mayor eficiencia, compare { true }.

Esto seguirá registrando discrepancias si se genera alguna excepción, pero ignorará los valores por completo.

Intentando más de una cosa
Por lo general, no es una buena idea probar más de una alternativa simultáneamente. No se garantiza que el comportamiento sea aislado y los informes y la visualización se vuelven un poco más difíciles. Aún así, a veces es útil.

Para probar más de una alternativa a la vez, agregue nombres a algunos trybloques:

requiere  "científico"

clase  MyWidget 
  incluye  Científico

  def  permite? ( usuario ) 
    ciencia  "permisos de widget"  hacer | e |
      e . use  {  modelo . check_user ( usuario ) . ¿válido?  }  # forma antigua

      e . intente ( "api" )  {  usuario . ¿pueden? ( : leer ,  modelo )  }  # API de nuevo servicio 
      e . intente ( "raw-sql" )  {  usuario . can_sql? ( : lectura ,  modelo )  }  # consulta sin formato 
    end 
  end 
end
Cuando se ejecuta el experimento, se prueban todos los comportamientos candidatos y cada observación candidata se compara con el control a su vez.

Sin control, solo candidatos
Defina los candidatos con trybloques con nombre , omita un usey pase un nombre de candidato a run:

experiment  =  MyExperiment . nuevo ( "varias formas" )  hacer | e |
  e . probar ( "primera vía" )   { ... } 
  e . try ( "second-way" )  { ... } 
end

Experimentar . ejecutar ( "segunda vía" )
El scienceayudante también conoce este truco:

ciencia  "varias formas" ,  ejecutar : "primera forma"  hacer | e |
  e . probar ( "primera vía" )   { ... } 
  e . try ( "second-way" )  { ... } 
end
Proporcionar datos de tiempo falsos
Si está escribiendo pruebas que dependen de valores de tiempo específicos, puede proporcionar duraciones predefinidas utilizando el fabricate_durations_for_testing_purposesmétodo, y el científico las informará en Scientist::Observation#durationlugar de los tiempos de ejecución reales.

ciencia  "aquí  no ocurre absolutamente nada sospechoso" | e |
  e . use  { ... }  # "control" 
  e . intente  { ... }  # "candidato" 
  e . fabricate_durations_for_testing_purposes (  "control"  =>  1.0 ,  "candidato"  =>  0.5  ) 
fin
fabricate_durations_for_testing_purposestoma un hash de valores de duración, codificados por nombres de comportamiento. (De forma predeterminada, Scientist usa "control"y "candidate", pero si los anula como se muestra en Probar más de una cosa o Sin control, solo candidatos , use nombres coincidentes aquí). Si no se proporciona un nombre, en su lugar se informará el tiempo de ejecución real.

Es Scientist::Experiment#cleanerprobable que esto no surja con el uso normal. Está aquí para facilitar la prueba del código que amplía Scientist.

Sin incluir al científico
Si necesita usar Scientist en un lugar donde no puede incluir el módulo Scientist, puede llamar a Scientist.run:

El científico . ejecutar  "permisos de widget"  hacer | e |
  e . use  {  modelo . check_user ( usuario ) . ¿válido?  } 
  e . prueba con  {  usuario . ¿pueden? ( : leer ,  modelo )  } 
fin
Hackear
Estar en una caja Unixy. Asegúrese de que haya un Bundler moderno disponible. script/testejecuta las pruebas unitarias. Todas las dependencias de desarrollo se instalan automáticamente. El científico requiere Ruby 2.3 o más reciente.

Envoltorios
RealGeeks / lab_tech es un motor Rails para usar esta biblioteca controlando, almacenando y analizando los resultados de los experimentos con ActiveRecord.
Alternativas
daylerees / científico (PHP)
proyecto científico / scientist.net (.NET)
joealcorn / laboratorio (Python)
rawls238 / Scientist4J (Java)
tomiaijo / científico (C ++)
trello / científico (node.js)
ziyasal / scientist.js (node.js, ES6)
TrueWill / tzientist (node.js, TypeScript)
TrueWill / paleontólogo (Deno, TypeScript)
yeller / laboratorio (Clojure)
lancew / científico (Perl 5)
lancew / ScientistP6 (Perl 6)
MadcapJake / Test-Lab (Perl 6)
cwbriones / científico (Elixir)
calavera / go-scientist (Ir)
jelmersnoeck / experiment (Ir)
spoptchev / científico (Kotlin / Java)
junkpiano / científico (Swift)
científico sin servidor (AWS Lambda)
fightmegg / científico (TypeScript, navegador / Node.js)
Mantenedores
@jbarnette , @jesseplusplus , @rick y @zerowidth
