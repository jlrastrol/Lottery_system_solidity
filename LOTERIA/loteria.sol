// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.7.0;
pragma experimental ABIEncoderV2;
import "./ERC20.sol";

contract loteria {

    
    ERC20Basic private token; //Instancia del contrato Token
    uint tokens_creados = 10000; // Número de tokens a crear

    //Direcciones
    address public owner;
    address public contrato;

    // Evento de compra de tokens
    event comprandoTokens(uint, address);

    // Constructor
    constructor() public{
        token = new ERC20Basic(tokens_creados);
        owner = msg.sender;
        contrato = address(this);

    }

    // ---------------------- TOKEN ----------------------

    // Establecer el precio de los Tokens en ethers
    function precioTokens(uint _numTokens) internal pure returns (uint){
        return _numTokens*(1 ether);
    }

    // Generar mas Tokens por la loteria
    function generaTokens(uint _numTokens) public unicamente(msg.sender) {
        token.increaseTotalSupply(_numTokens);
    }

    // Modificador para hacer funciones solamente accesibles por el owner del contrato
    modifier unicamente(address _direccion) {
        require(_direccion == owner, "No tienes permisos para ejecutar la función");
        _;
    }

    // Comprar Tokens
    function comprarTokens(uint _numTokens) public payable {
        uint coste = precioTokens(_numTokens); // Calcular el coste de los Tokens
        require(msg.value >= coste, "No tiene fondos suficientes para comprar este número de Tokens."); // Se requiere que el valor de ethers pagados sea equivalente al coste
        uint returnValue = msg.value - coste; // Diferencia de Tokens
        msg.sender.transfer(returnValue); // Transferencia de la diferencia
        uint balance = tokensDisponibles(); // Obtener el balance de Tokens del contrato
        require(_numTokens <= balance, "Compra un número de Tokens adecuado."); // Filtro para evaluar los tokens a comprar con los tokens disponibles
        token.transfer(msg.sender,_numTokens);// Transferencia de Tokens al comprador
        emit comprandoTokens(_numTokens, msg.sender); // Emitir evento de compra de tokens
        
    }

    // Balance de tokens en el contrato de loteria
    function tokensDisponibles() public view returns (uint){
        return token.balanceOf(contrato);

    }

    // Balance de tokens acumulados en el bote
    function bote() public view returns (uint){
        return token.balanceOf(owner);
    }

    // Balance de tokens de una persona
    function misTokens() public view returns (uint){
        return token.balanceOf(msg.sender);

    }

    // ---------------------- LOTERÍA ----------------------

    uint public precioBoleto = 5; // Precio del boleto
    mapping(address => uint[]) personaBoletos; // Relación entre la persona que compra los boletos y los número de los boletos
    mapping(uint => address) ADN_boleto; // Relación necesaria para identificar al ganador
    uint randNonce = 0; //Número aleatorio
    uint [] boletosComprados; // Boletos generados

    // Eventos
    event boletoComprado(uint, address); // Evento cuando se compra un boleto
    event boletoGanador(uint); //Evento del ganador
    event tokensDevueltos(uint, address); //Evento para devolver tokens


    // Función para comprar boletos de loteria
    function compraBoleto(uint _boletos) public {
        // Precio total de los boletos
        uint precio_total = precioBoleto * _boletos;
        // Filtrado de los tokens a pagar
        require(precio_total <= misTokens(), "Necesitas mas tokens.");
        // Transferencia de los tokens al owner -> bote/premio

        /* El cliente paga la atraccion en Tokens:
        - Ha sido necesario crear una funcion en ERC20.sol con el nombre de: 'transferencia_loteria'
        debido a que en caso de usar el Transfer o TransferFrom las direcciones que se escogian 
        para realizar la transccion eran equivocadas. Ya que el msg.sender que recibia el metodo Transfer o
        TransferFrom era la direccion del contrato. Y debe ser la direccion de la persona fisia.
        */
        token.transferLoteria(msg.sender, owner, precio_total);

        /*
        Lo que esto haria es tomar la marca de tiempo now, el msg.sender y un nonce
        (un numero que solo se utiliza una vez, para que no ejecutemos dos veces la misma 
        funcion de hash con los mismos parametros de entrada) en incremento.
        Luego se utiliza keccak256 para convertir estas entradas a un hash aleatorio, 
        convertir ese hash a un uint y luego utilizamos % 10000 para tomar los ultimos 4 digitos.
        Dando un valor aleatorio entre 0 - 9999.
        */
        for (uint i = 0; i< _boletos; i++){
            uint random = uint(keccak256(abi.encodePacked(now,msg.sender, randNonce))) % 10000;
            randNonce++;
            // Almacenamos los datos de los boletos 
            personaBoletos[msg.sender].push(random);
            // Numero de boleto comprado
            boletosComprados.push(random);
            // Asignacion del ADN del boleto para tener un ganador 
            ADN_boleto[random] = msg.sender;
            // Emision del evento 
            emit boletoComprado(random , msg.sender);
        }
    }

    // Visualizar los boletos comprados por una persona
    function misBoletos() public view returns (uint[] memory){
        return personaBoletos[msg.sender];
    }

    // Función para generar un ganador e ingresarle los Tokens
    function generarGanador() public unicamente(msg.sender){
        // Debe haber boletos comprados para generar un ganador
        require(boletosComprados.length > 0, "No hay boletos comprados.");
        // Declarar la longitud del array
        uint long = boletosComprados.length;
        // Aleatoriamente elijo un número entre: 0 - long
        // 1 - Eleccion de una posicion aleatoria del array 
        uint posicionGanador = uint(uint(keccak256(abi.encodePacked(now))) % long);
        // 2- Seleccion del numero aleatorio mediante la posicion del array aleatoria
        uint eleccion = boletosComprados[posicionGanador];
        // Emisión del evento del ganador
        emit boletoGanador(eleccion);
        // Recuperar la dirección del ganador
        address direccionGanador = ADN_boleto[eleccion];
        // Enviarle los tokens del premio al ganador
        token.transferLoteria(msg.sender,direccionGanador,bote());
    }

    // Devolución de los tokens
    function devolverTokens(uint _numTokens) public payable{
        // El número de tokens debe ser mayor que 0
        require( _numTokens > 0, "El número de tokens tiene que ser mayor que 0.");
        // El usuario debe tener los tokens
        require(_numTokens <= misTokens(), "No tienes los tokens que deseas devolver.");
        // DEVOLUCION:
        // 1. El cliente devuelva los tokens
        // 2. La loteria paga los tokens devueltos en ethers    
        token.transferLoteria(msg.sender, contrato, _numTokens);
        msg.sender.transfer(precioTokens(_numTokens));
        //Emisión del evento
        emit tokensDevueltos(_numTokens,msg.sender);
    }


}