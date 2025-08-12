<?php

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DepartmentsTableSeeder extends Seeder
{
    public function run()
    {
        // se não existir, insere; se já existir, apenas atualiza nome
        if (! DB::table('departments')->where('id', 1)->exists()) {
            DB::table('departments')->insert([
                'id'         => 1,
                'external_id'=> (string) Str::uuid(),
                'name'       => 'Management',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        } else {
            DB::table('departments')->where('id', 1)->update([
                'name'       => 'Management',
                'updated_at' => now(),
            ]);
        }

        // pivot: não duplica
        DB::table('department_user')->updateOrInsert(
            ['department_id' => 1, 'user_id' => 1],
            [] // nada pra atualizar
        );
    }
}
