import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {

  final _formKey = GlobalKey<FormState>();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();


  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;


  Color get primaryPurple => Theme.of(context).colorScheme.primary;
  Color get lightPurpleBg => Theme.of(context).colorScheme.primary.withOpacity(0.08);
  Color get lightIconBg => AppTheme.colorsOf(context).chipBackground;


  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }


  void updatePassword(){

    if(!_formKey.currentState!.validate()) return;

    if(newPasswordController.text != confirmPasswordController.text){

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords don't match"),
        ),
      );

      return;
    }


    // Firebase update password will be here

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Password updated successfully"),
      ),
    );

  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(

automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,


        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.iconTheme?.color,
          ),
          onPressed: ()=>Navigator.pop(context),
        ),


        title: Text(
          "Change Password",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,

      ),



      body: SingleChildScrollView(

        padding: const EdgeInsets.all(24),

        child: Form(

          key: _formKey,

          child: Column(

            children: [


              Container(

                height:90,
                width:90,

                decoration: BoxDecoration(
                  color:lightPurpleBg,
                  shape:BoxShape.circle,
                ),

                child: Icon(
                  Icons.lock,
                  size:40,
                  color:primaryPurple,
                ),

              ),


              const SizedBox(height:20),



              Text(
                "Keep your account secure",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),


              const SizedBox(height:8),


              Text(
                "Choose a strong password and don’t share it\nwith anyone.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),



              const SizedBox(height:28),



              _passwordField(
                label:"Current Password",
                hint:"Enter your current password",
                controller:currentPasswordController,
                obscure:obscureCurrent,
                toggle:(){
                  setState(() {
                    obscureCurrent=!obscureCurrent;
                  });
                },
              ),


              const SizedBox(height:16),



              _passwordField(
                label:"New Password",
                hint:"Enter your new password",
                controller:newPasswordController,
                obscure:obscureNew,
                toggle:(){
                  setState(() {
                    obscureNew=!obscureNew;
                  });
                },
              ),



              const SizedBox(height:12),



              _strengthIndicator(),



              const SizedBox(height:12),



              _passwordField(
                label:"Confirm New Password",
                hint:"Re-enter your new password",
                controller:confirmPasswordController,
                obscure:obscureConfirm,
                toggle:(){
                  setState(() {
                    obscureConfirm=!obscureConfirm;
                  });
                },
              ),



              const SizedBox(height:20),



              Container(

                padding:const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? lightIconBg.withOpacity(0.12)
                      : lightIconBg,
                  borderRadius: BorderRadius.circular(16),
                ),

                child:Row(

                  children:[

                    Icon(
                      Icons.shield_outlined,
                      color:primaryPurple,
                    ),

                    const SizedBox(width:12),


                    Expanded(

                      child: Text(
                        "Password must be at least 6 characters long.",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),

                    )

                  ],

                ),

              ),



              const SizedBox(height:24),



              SizedBox(

                width:double.infinity,
                height:56,

                child:ElevatedButton(

                  onPressed:updatePassword,

                  style:ElevatedButton.styleFrom(
                    backgroundColor:primaryPurple,
                    shape:RoundedRectangleBorder(
                      borderRadius:BorderRadius.circular(16),
                    ),
                  ),


                  child:const Text(
                    "Update Password",
                    style:TextStyle(
                      color:Colors.white,
                      fontSize:16,
                      fontWeight:FontWeight.bold,
                    ),
                  ),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }





Widget _passwordField({

 required String label,
 required String hint,
 required TextEditingController controller,
 required bool obscure,
 required VoidCallback toggle,

}){


return Container(

padding:const EdgeInsets.symmetric(horizontal:12),

decoration:BoxDecoration(

color: Theme.of(context).cardColor,

borderRadius: BorderRadius.circular(16),

border: Border.all(
color: Theme.of(context).dividerColor,
),

),


child:TextFormField(

controller:controller,

obscureText:obscure,


validator:(value){

if(value==null || value.isEmpty){

return "Required";

}

if(value.length<6){

return "Minimum 6 characters";

}

return null;

},


decoration:InputDecoration(

labelText:label,

hintText:hint,

border:InputBorder.none,


suffixIcon:IconButton(

icon:Icon(

obscure
? Icons.visibility_outlined
: Icons.visibility_off_outlined,

),

onPressed:toggle,

),

),

),

);

}





Widget _strengthIndicator(){

final length=newPasswordController.text.length;


return Row(

children:[

Expanded(

child:LinearProgressIndicator(

value:length/12,

minHeight:5,

backgroundColor: Theme.of(context).dividerColor,

color:primaryPurple,

),

),


const SizedBox(width:10),


Text(
length<6
?"Weak"
:length<10
?"Medium"
:"Strong",

style: TextStyle(
fontWeight: FontWeight.bold,
color: Theme.of(context).textTheme.bodyLarge?.color,
),

)

],

);

}

}