
import subprocess

class line:
	def __init__(self,firstSt=" "):
		self.tex = firstSt

	def Newcase(self,case,B=False):
		if B:
			self.tex = self.tex + " & " + str(case)
		else:
			self.tex = self.tex + " & \\textbf{ " + str(case) + "} "

	def Newcase3g(self,case,B=False):

		if B:
			self.tex = self.tex + " & \\textbf{ " + "%.3g"%case + "} "
		else:
			self.tex = self.tex + " & " + "%.3g"%case




	def NewcaseMath(self,case):
		self.tex = self.tex + " & $" + str(case) + "$ "

	def End(self):
		self.tex = self.tex + "\\tabularnewline\n"



class MatToTex:

	def __init__(self,Mat,label,filepath,filename,Flag_Bold=True):

		self.Nr = Mat.shape[0]
		self.Nc = Mat.shape[1]

		self.Mat = Mat
		self.label = label
		self.B = Flag_Bold
		self.path = filepath
		self.file = filename

		self.TEXT = "\\begin{tabular}"

		temp = "{c"

		for nc in xrange(0,self.Nc):
			temp = temp + "c"

		self.TEXT = self.TEXT + temp + "}\n"

	def Newline(self,newline):
		self.TEXT = self.TEXT + newline.tex +'\n'

	def hline(self):
		self.TEXT = self.TEXT + "\hline" +'\n'


	def End(self):
		self.hline()
		self.TEXT = self.TEXT + "\end{tabular}\n"

		log = open(self.path +"/" +self.file +".tex", 'w')
		log.write(self.TEXT)
		log.close()

	def TabPierre(self):

		self.hline()

		l = line(" ")

		for nc in xrange(0,self.Nc):
			l.NewcaseMath(self.label[nc])

		l.End()
		self.Newline(l)

		for m in xrange(0,self.Nr):
			self.Newline("\hline")

			l = line("$" + self.label[m] +"$")

			for nc in xrange(0,self.Nc):
				if (nc==m):
					l.Newcase3g(self.Mat[m,nc],True)
				else:
					l.Newcase3g(self.Mat[m,nc],False)

			l.End()
			self.Newline(l)

		self.End()


	def Tab01(self):

		self.hline()

		l = line(" ")

		for nc in xrange(0,self.Nc):
			l.NewcaseMath(self.label[nc])

		l.End()
		self.Newline(l)

		Flag_Impaire = True;
		for m in xrange(0,self.Nr):
			self.hline()

			if Flag_Impaire:
				l = line("\\rowcolor{grisclair} $" + self.label[m] +"$")
				Flag_Impaire = False;
			else:
				l = line("$" + self.label[m] +"$")
				Flag_Impaire = True;

			idmax = self.Mat[m,:].argmax()

			for nc in xrange(0,self.Nc):
				if (nc==idmax):
					l.Newcase3g(self.Mat[m,nc],True)
				else:
					l.Newcase3g(self.Mat[m,nc],False)

			l.End()
			self.Newline(l)

		self.End()

	def Tab00(self):

		self.hline()

		l = line(" ")

		for nc in xrange(0,self.Nc):
			l.NewcaseMath(self.label[nc])

		l.End()
		self.Newline(l)


		for m in xrange(0,self.Nr):
			self.hline()
			l = line("$" + self.label[m] +"$")

			idmax = self.Mat[m,:].argmax()
			print str(idmax)
			for nc in xrange(0,self.Nc):
				if (nc==idmax):
					l.Newcase3g(self.Mat[m,nc],True)
				else:
					l.Newcase3g(self.Mat[m,nc],False)

			l.End()
			self.Newline(l)

		self.End()


class DocTabTex:

	def __init__(self,Mat,label,TypeTab="Tab01",caption=" ",Docpath="",TabPath="",Docname="docname",TabName="tabname",option='t',commentaire="%"):

		self.doctex = commentaire + '\n'
		self.TAB = MatToTex(Mat,label,TabPath,TabName,option)
		self.TypeTab = TypeTab
		self.path = Docpath
		self.file = Docname
		self.opt = option
		self.caption = caption

	def preambule(self):

		self.doctex = self.doctex + "\documentclass{article}\n"
		self.doctex = self.doctex + "\usepackage[T1]{fontenc}\n"
		self.doctex = self.doctex + "\usepackage[latin9]{inputenc}\n"
		self.doctex = self.doctex + "\usepackage{float}\n"
		self.doctex = self.doctex + "\usepackage{amsmath}\n"
		self.doctex = self.doctex + "\usepackage{amssymb}\n"
		self.doctex = self.doctex + "\usepackage{colortbl}\n"
		self.doctex = self.doctex + "\usepackage{graphicx}\n"
		self.doctex = self.doctex + "\definecolor{grisclair}{gray}{0.8}\n"
		self.doctex = self.doctex + "\\begin{document}\n"
		self.doctex = self.doctex + "\n"
		self.doctex = self.doctex + "\\begin{table}["+self.opt+"]\n"
		self.doctex = self.doctex + "\\begin{centering}\n"

	def include(self):

		self.doctex = self.doctex + "\include{"+self.TAB.file+"}\n"
		self.doctex = self.doctex + "\n"

	def End(self):
		self.doctex = self.doctex + "\n"
		self.doctex = self.doctex + "\par\end{centering}\n"
		self.doctex = self.doctex + "\caption{"+self.caption+"}\n"
		self.doctex = self.doctex + "\end{table}\n"
		self.doctex = self.doctex + "\end{document}\n"
		log = open(self.path + "/" +self.file +".tex", 'w')
		log.write(self.doctex)
		log.close()


	def creatTex(self):

		if (self.TypeTab=="Tab00"):
			self.TAB.Tab00()
		elif (self.TypeTab=="Tab01"):
			self.TAB.Tab01()
		elif (self.TypeTab=="TabPierre"):
			self.TAB.TabPierre()
		else:
			print "format tableau pas connu"

		self.preambule()
		self.include()
		self.End()

	def creatpdf(self):
		subprocess.call(["pdflatex", self.file +".tex"])
		subprocess.call(["cp", self.file +".pdf", self.path +"/"+ self.file +".pdf"])
		subprocess.call(["cp", self.file +".tex", self.path +"/"+ self.file +".tex"])
		subprocess.call(["cp", self.TAB.file +".tex", self.TAB.path +"/"+ self.TAB.file +".tex"])
		subprocess.call(["rm", self.file +".pdf"])
		subprocess.call(["rm", self.file +".tex"])
		subprocess.call(["rm", self.file +".aux"])
		subprocess.call(["rm", self.file +".log"])
		subprocess.call(["rm", self.TAB.file +".aux"])
		subprocess.call(["rm", self.TAB.file +".tex"])

