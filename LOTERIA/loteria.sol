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
    event boletoComprado(uint); // Evento cuando se compra un boleto
    event boletoGanador(uint); //Evento del ganador


}