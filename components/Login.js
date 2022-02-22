import Image from "next/image";
import { useMoralis } from "react-moralis";


function Login() {
    const {authenticate}= useMoralis();
    return (
        <div className="bg-black relative text-white">
            <h1>Please Link Your Meta-mask wallet </h1>
            <div className="flex flex-col absolute z-50 h-4/6 w-full items-center justify-center space-y-4">

             <button onClick={authenticate} className="bg-green-500 rounded-lg p-5 font-bold "> Login With Metamask</button>

            </div>

        </div>

    );
}

export default Login;
