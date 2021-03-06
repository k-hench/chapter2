if(variant.getNAlleles()!=2 || !variant.hasAttribute("AA")) return true;
final String aa = variant.getAttributeAsString("AA","");
if(!variant.getAlleles().get(1).getDisplayString().equalsIgnoreCase(aa)) return true;
VariantContextBuilder vb=new VariantContextBuilder(variant);

Allele oldalt =  variant.getAlleles().get(1);
Allele oldref =  variant.getAlleles().get(0);
Allele ref= Allele.create(oldalt.getDisplayString(),true);
Allele alt= Allele.create(oldref.getDisplayString(),false);

vb.alleles(Arrays.asList(ref,alt));

List<Genotype> genotypes= new ArrayList<>();
for(Genotype g: variant.getGenotypes())
    {
    if(!g.isCalled()) { genotypes.add(g); continue;}
    GenotypeBuilder gb = new GenotypeBuilder(g);
    List<Allele> alleles = new ArrayList<>();
    for(Allele a:g.getAlleles())
        {
        if(a.equals(oldalt)) { a=ref;}
        else if(a.equals(oldref)) { a=alt;}
        alleles.add(a);
        }
    if(g.hasPL()) {
        int pl[] = g.getPL();
        int pl2[] = new int[pl.length];
        for(int i=0;i< pl.length;i++) pl2[i]=pl[(pl.length-1)-i];
        gb.PL(pl2);
        }
    genotypes.add(gb.alleles(alleles).make());
    }

vb.attribute("AC",variant.getGenotypes().stream().flatMap(G->G.getAlleles().stream()).filter(A->A.equals(oldref)).count());
 vb.genotypes(genotypes);
return vb.make();
